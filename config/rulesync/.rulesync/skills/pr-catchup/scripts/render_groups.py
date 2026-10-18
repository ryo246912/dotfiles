"""hunks.json と groups.json から「変更グループ」の HTML を作り、index.html に差し込む。

index.html の `<!-- pr-catchup:groups:start -->` と `<!-- pr-catchup:groups:end -->` の間を置き換える。
すべての hunk がちょうど 1 つのグループに入っていなければ、何も書き換えずに終了コード 1 で終わる。

groups.json の書式（グループは読む順に並べる）:

    {
      "groups": [
        {
          "id": "g1",
          "title": "URL・ホスト判定の共通基盤",
          "kind": "feature",          # feature / fix / refactor / test / docs / config / chore / generated
          "risk": "high",             # high（要注意）/ medium（注意）/ low（低リスク）
          "summary": "一覧に出す 1 文",
          "intent": "なぜこの変更をするのか",
          "impact": "影響範囲（任意）",
          "checkpoints": ["レビューで確かめること（任意）"],
          "prs": [123],               # stack のとき、どの PR の変更か（任意）
          "hunks": ["h001", "h002"],
          "hunk_notes": {"h002": "この hunk だけの補足（任意）"}
        }
      ]
    }

kind が generated のグループ（lockfile・生成物・スナップショット）は、折りたたんで最後に出す。
"""

import argparse
import html
import json
import re
import sys
from pathlib import Path

RISK_LABELS = {"high": "要注意", "medium": "注意", "low": "低リスク"}
KIND_LABELS = {
    "feature": "feature",
    "fix": "fix",
    "refactor": "refactor",
    "test": "test",
    "docs": "docs",
    "config": "config",
    "chore": "chore",
    "generated": "generated",
}
MARKER = re.compile(r"(<!-- pr-catchup:groups:start -->)(.*?)(<!-- pr-catchup:groups:end -->)", re.S)
LARGE_HUNK_LINES = 300

esc = html.escape


def validate(hunks: dict[str, dict], groups: list[dict]) -> list[str]:
    errors: list[str] = []
    owner: dict[str, str] = {}
    for group in groups:
        for key in ("id", "title", "kind", "risk", "summary", "intent", "hunks"):
            if key not in group:
                errors.append(f"{group.get('id', '?')}: {key} が無い")
        if group.get("risk") not in RISK_LABELS:
            errors.append(f"{group.get('id')}: risk は {'/'.join(RISK_LABELS)} のどれか")
        if group.get("kind") not in KIND_LABELS:
            errors.append(f"{group.get('id')}: kind は {'/'.join(KIND_LABELS)} のどれか")
        for hunk_id in group.get("hunks", []):
            if hunk_id not in hunks:
                errors.append(f"{group['id']}: 存在しない hunk {hunk_id}")
            elif hunk_id in owner:
                errors.append(f"{hunk_id} が {owner[hunk_id]} と {group['id']} の両方に入っている")
            else:
                owner[hunk_id] = group["id"]
        for hunk_id in group.get("hunk_notes", {}):
            if hunk_id not in group.get("hunks", []):
                errors.append(f"{group['id']}: hunk_notes の {hunk_id} がグループの hunks に無い")
    missing = [hunk_id for hunk_id in hunks if hunk_id not in owner]
    if missing:
        errors.append(f"どのグループにも入っていない hunk: {', '.join(missing)}")
    return errors


def render_hunk(hunk: dict, note: str | None, blob_url: str | None) -> str:
    path = esc(hunk["path"])
    if hunk["old_path"] != hunk["path"]:
        path = f"{esc(hunk['old_path'])} → {path}"
    if blob_url and hunk["status"] != "deleted":
        path = f'<a href="{esc(blob_url)}/{esc(hunk["path"])}#L{hunk["new_start"]}">{path}</a>'
    rows = []
    for sign, old_no, new_no, text in hunk["lines"]:
        kind = {"+": "add", "-": "del", "\\": "meta"}.get(sign, "ctx")
        rows.append(
            f'<tr class="{kind}"><td class="ln">{old_no or ""}</td><td class="ln">{new_no or ""}</td>'
            f'<td class="sign">{esc(sign) if sign in "+-" else ""}</td><td class="code">{esc(text)}</td></tr>'
        )
    body = (
        f'<table class="diff"><tbody>{"".join(rows)}</tbody></table>'
        if rows
        else f'<p class="evidence">差分の行なし（{esc(hunk["status"])}）</p>'
    )
    note_html = f'<p class="hunk-note">{esc(note)}</p>' if note else ""
    open_attr = "" if len(hunk["lines"]) > LARGE_HUNK_LINES else " open"
    return (
        f'<details class="hunk" id="{hunk["id"]}"{open_attr}><summary><span class="hunk-id">{hunk["id"]}</span>'
        f'<code class="hunk-path">{path}</code><span class="hunk-range">{esc(hunk["header"].split(" @@")[0] + " @@" if hunk["lines"] else "")}</span>'
        f'<span class="added">+{hunk["added"]}</span> <span class="removed">−{hunk["removed"]}</span></summary>'
        f"{note_html}<div class=\"diff-wrap\">{body}</div></details>"
    )


def render(hunks: dict[str, dict], groups: list[dict], blob_url: str | None) -> str:
    groups = [g for g in groups if g["kind"] != "generated"] + [g for g in groups if g["kind"] == "generated"]
    overview, details = [], []
    for group in groups:
        members = [hunks[hunk_id] for hunk_id in group["hunks"]]
        files = len({hunk["path"] for hunk in members})
        risk = f'<span class="risk risk-{group["risk"]}">{RISK_LABELS[group["risk"]]}</span>'
        kind = f'<span class="tag">{KIND_LABELS[group["kind"]]}</span>'
        prs = "".join(f'<span class="tag">#{n}</span>' for n in group.get("prs", []))
        checkpoints = group.get("checkpoints", [])
        count = f'<span class="checkpoint-count">確認ポイント {len(checkpoints)}</span>' if checkpoints else ""
        overview.append(
            f'<li class="group-row risk-border-{group["risk"]}" data-group="{esc(group["id"])}">'
            f'<a href="#group-{esc(group["id"])}"><span class="group-title">{esc(group["title"])}</span>'
            f'<span class="group-summary">{esc(group["summary"])}</span></a>'
            f'<span class="group-tags">{count}{kind}{prs}<span class="tag">{files} files / {len(members)} hunks</span>{risk}'
            f'<span class="done-mark" aria-label="確認済み">✓</span></span></li>'
        )
        impact = f'<p><strong>影響範囲:</strong> {esc(group["impact"])}</p>' if group.get("impact") else ""
        checklist = (
            "<ul class=\"checkpoints\">" + "".join(f"<li>{esc(c)}</li>" for c in checkpoints) + "</ul>"
            if checkpoints
            else ""
        )
        notes = group.get("hunk_notes", {})
        hunk_html = "".join(render_hunk(hunk, notes.get(hunk["id"]), blob_url) for hunk in members)
        open_attr = "" if group["kind"] == "generated" else " open"
        details.append(
            f'<article class="group risk-border-{group["risk"]}" id="group-{esc(group["id"])}">'
            f'<header class="group-head"><div>{risk} <h3>{esc(group["title"])}</h3>'
            f'<p class="intent"><strong>意図:</strong> {esc(group["intent"])}</p>{impact}{checklist}</div>'
            f'<label class="approve"><input type="checkbox" data-group="{esc(group["id"])}" /> 確認済み</label></header>'
            f'<details class="group-diff"{open_attr}><summary>差分 {files} files / {len(members)} hunks</summary>'
            f"{hunk_html}</details></article>"
        )
    all_hunks = list(hunks.values())
    stats = (
        f'data-files="{len({h["path"] for h in all_hunks})}" data-hunks="{len(all_hunks)}" '
        f'data-added="{sum(h["added"] for h in all_hunks)}" data-removed="{sum(h["removed"] for h in all_hunks)}"'
    )
    return (
        f'\n<div id="diff-groups" {stats}>'
        f'<ol class="group-list">{"".join(overview)}</ol>'
        f'<h3 class="sub">変更グループ詳細</h3>{"".join(details)}</div>\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--hunks", required=True, type=Path)
    parser.add_argument("--groups", required=True, type=Path)
    parser.add_argument("--html", required=True, type=Path, help="差し込み先の index.html")
    parser.add_argument("--blob-url", help="https://github.com/<owner>/<repo>/blob/<head SHA>（ファイルへのリンク用）")
    args = parser.parse_args()

    hunks = {hunk["id"]: hunk for hunk in json.loads(args.hunks.read_text())["hunks"]}
    groups = json.loads(args.groups.read_text())["groups"]
    errors = validate(hunks, groups)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    page = args.html.read_text()
    if not MARKER.search(page):
        print("index.html に pr-catchup:groups のマーカーが無い", file=sys.stderr)
        return 1
    fragment = render(hunks, groups, args.blob_url)
    args.html.write_text(MARKER.sub(lambda m: m.group(1) + fragment + m.group(3), page, count=1))
    print(f"{len(groups)} groups / {len(hunks)} hunks を差し込んだ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
