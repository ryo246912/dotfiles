"""変更グループ（groups.json）を検査し、差分付きの HTML 片を作る（HTML は render_brief.py が組み立てる）。

    python3 render_groups.py --hunks hunks.json --groups groups.json --check draft   # 振り分けだけ検査
    python3 render_groups.py --hunks hunks.json --groups groups.json --check full    # 解説まで検査

draft はすべての hunk がちょうど 1 つのグループに入っているかと id・title・kind を、full はさらに
risk・summary・intent を検査する。問題があれば終了コード 1。

groups.json の書式（グループは読む順に並べる）:

    {
      "groups": [
        {
          "id": "g1",
          "title": "URL・ホスト判定の共通基盤",
          "kind": "feature",          # feature / fix / refactor / test / docs / config / chore / generated
          "hunks": ["h001", "h002"],
          "prs": [123],               # stack のとき、どの PR の変更か（任意）
          # ここまでを情報集めの段階で書く。以下は文章の段階で足す
          "risk": "high",             # high（要注意）/ medium（注意）/ low（低リスク）
          "summary": "一覧に出す 1 文",
          "intent": "なぜこの変更をするのか",
          "impact": "影響範囲（任意）",
          "checkpoints": ["レビューで確かめること（任意）"],
          "hunk_notes": {"h002": "この hunk だけの補足（任意）"}
        }
      ]
    }

kind が generated のグループ（lockfile・生成物・スナップショット）は、折りたたんで最後に出す。
"""

import argparse
import html
import json
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
LARGE_HUNK_LINES = 300

esc = html.escape


def validate(hunks: dict[str, dict], groups: list[dict], stage: str = "full") -> list[str]:
    errors: list[str] = []
    owner: dict[str, str] = {}
    keys = ("id", "title", "kind", "hunks") + (("risk", "summary", "intent") if stage == "full" else ())
    ids = [group.get("id") for group in groups]
    for group_id in sorted({i for i in ids if ids.count(i) > 1}, key=str):
        errors.append(f"グループの id が重複している: {group_id}")
    kinds = [group.get("kind") for group in groups]
    if "generated" in kinds and any(k != "generated" for k in kinds[kinds.index("generated"):]):
        errors.append("generated のグループは最後に並べる（並び順がグループ番号になるため）")
    for group in groups:
        for key in keys:
            if key not in group:
                errors.append(f"{group.get('id', '?')}: {key} が無い")
        if stage == "full" and group.get("risk") not in RISK_LABELS:
            errors.append(f"{group.get('id')}: risk は {'/'.join(RISK_LABELS)} のどれか")
        if group.get("kind") not in KIND_LABELS:
            errors.append(f"{group.get('id')}: kind は {'/'.join(KIND_LABELS)} のどれか")
        for hunk_id in group.get("hunks", []):
            if hunk_id not in hunks:
                errors.append(f"{group.get('id', '?')}: 存在しない hunk {hunk_id}")
            elif hunk_id in owner:
                errors.append(f"{hunk_id} が {owner[hunk_id]} と {group.get('id', '?')} の両方に入っている")
            else:
                owner[hunk_id] = group.get("id", "?")
        for hunk_id in group.get("hunk_notes", {}):
            if hunk_id not in group.get("hunks", []):
                errors.append(f"{group.get('id', '?')}: hunk_notes の {hunk_id} がグループの hunks に無い")
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


def size_bar(added: int, removed: int, scale: int) -> str:
    """追加・削除の行数を、scale 行を 100% とした横棒にする。"""
    add = 100 * added / scale if scale else 0
    rem = 100 * removed / scale if scale else 0
    return (
        f'<span class="sizebar" title="+{added} −{removed}"><span class="add" style="width:{add:.1f}%"></span>'
        f'<span class="del" style="width:{rem:.1f}%"></span></span>'
    )


def render_file_map(hunks: dict[str, dict], groups: list[dict], numbers: dict[str, int]) -> str:
    """変更ファイルをディレクトリごとに並べ、ファイルごとの変更量と、どのグループに入っているかを示す。"""
    files: dict[str, dict] = {}
    for group in groups:
        for hunk_id in group["hunks"]:
            hunk = hunks[hunk_id]
            entry = files.setdefault(hunk["path"], {"added": 0, "removed": 0, "groups": []})
            entry["added"] += hunk["added"]
            entry["removed"] += hunk["removed"]
            if group["id"] not in [g["id"] for g in entry["groups"]]:
                entry["groups"].append(group)
    scale = max((f["added"] + f["removed"] for f in files.values()), default=0)
    rows, current_dir = [], None
    for path in sorted(files):
        directory, _, name = path.rpartition("/")
        if directory != current_dir:
            rows.append(f'<div class="dir">{esc(directory or ".")}/</div>')
            current_dir = directory
        entry = files[path]
        chips = "".join(
            f'<a class="chip risk-{g["risk"]}" href="#group-{esc(g["id"])}">{numbers[g["id"]]}. {esc(g["title"])}</a>'
            for g in entry["groups"]
        )
        rows.append(
            f'<div class="file"><code title="{esc(path)}">{esc(name)}</code>'
            f'{size_bar(entry["added"], entry["removed"], scale)}<span class="chips">{chips}</span></div>'
        )
    return (
        f'<details class="file-map"><summary>変更ファイルの地図（{len(files)} files）</summary>{"".join(rows)}</details>'
    )


def render(hunks: dict[str, dict], groups: list[dict], blob_url: str | None) -> str:
    groups = [g for g in groups if g["kind"] != "generated"] + [g for g in groups if g["kind"] == "generated"]
    numbers = {group["id"]: index for index, group in enumerate(groups, start=1)}
    scale = max((sum(hunks[h]["added"] + hunks[h]["removed"] for h in g["hunks"]) for g in groups), default=0)
    overview, details = [], []
    for group in groups:
        members = [hunks[hunk_id] for hunk_id in group["hunks"]]
        added = sum(hunk["added"] for hunk in members)
        removed = sum(hunk["removed"] for hunk in members)
        files = len({hunk["path"] for hunk in members})
        risk = f'<span class="risk risk-{group["risk"]}">{RISK_LABELS[group["risk"]]}</span>'
        kind = f'<span class="tag">{KIND_LABELS[group["kind"]]}</span>'
        prs = "".join(f'<span class="tag">#{n}</span>' for n in group.get("prs", []))
        checkpoints = group.get("checkpoints", [])
        count = f'<span class="checkpoint-count">確認ポイント {len(checkpoints)}</span>' if checkpoints else ""
        overview.append(
            f'<li class="group-row risk-border-{group["risk"]}" data-group="{esc(group["id"])}">'
            f'<a href="#group-{esc(group["id"])}"><span class="group-title">{numbers[group["id"]]}. {esc(group["title"])}</span>'
            f'<span class="group-summary">{esc(group["summary"])}</span></a>'
            f'<span class="group-tags">{count}{kind}{prs}<span class="tag">{files} files / {len(members)} hunks</span>'
            f'{size_bar(added, removed, scale)}{risk}'
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
            f'<header class="group-head"><div>{risk} <h3>{numbers[group["id"]]}. {esc(group["title"])}</h3>'
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
        f'{render_file_map(hunks, groups, numbers)}'
        f'<ol class="group-list">{"".join(overview)}</ol>'
        f'<h3 class="sub">変更グループ詳細</h3>{"".join(details)}</div>\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--hunks", required=True, type=Path)
    parser.add_argument("--groups", required=True, type=Path)
    parser.add_argument("--check", choices=["draft", "full"], default="full")
    args = parser.parse_args()

    hunks = {hunk["id"]: hunk for hunk in json.loads(args.hunks.read_text())["hunks"]}
    groups = json.loads(args.groups.read_text())["groups"]
    errors = validate(hunks, groups, args.check)
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print(f"ok: {len(groups)} groups / {len(hunks)} hunks")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
