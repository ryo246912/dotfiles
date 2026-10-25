"""仕組み化のチェックリスト（agent-lessons の `escalation.md`）を読み書きし、印を付けた教訓を ruled にする。

    python3 escalation.py --apply   # [x] を付けた項目の教訓を ruled にし、項目を「済み」へ移す

教訓は注入して守らせるより、lint・hook・テスト・ルールファイルで機械的に防ぐほうが確実。active になった後も
指摘され続ける教訓を、週次の apply_plan.py がこのチェックリストの「未対応」に足す（モデルが書いた仕組みの案付き）。
ユーザーが仕組みを入れたら `[ ]` を `[x]` にし、`仕組み:` に入れたもの（PR の URL など）を書く。`mise run lessons:sync`
（週次の段階 0 でも呼ばれる）がこのスクリプトを呼び、その教訓を ruled（注入しない）にする。

項目の書式（`## 未対応` と `## 済み` の下に並ぶ。2 行目以降は 2 文字下げ）:

    - [ ] <教訓のタイトル> — `lessons/<source>/<scope_key>/<key>.md`
      - 案: <仕組みの案>
      - 仕組み: <入れた仕組み。ユーザーが書く>
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys

import lessonlib as L

PATH = L.LESSONS_DIR / "escalation.md"
TODO, DONE = "未対応", "済み"
HEADER = """# 仕組み化のチェックリスト

注入しても指摘され続ける教訓を、lint・hook・テスト・ルールファイル（CLAUDE.md・AGENTS.md など）で防ぐための一覧。
仕組みを入れたら `[ ]` を `[x]` にし、`仕組み:` に入れたもの（PR の URL など）を書いて `mise run lessons:sync` する。
その教訓は ruled になり、SessionStart で注入されなくなる。項目は週次の lessons-harvest が足す。
"""
ITEM = re.compile(r"^- \[([ xX])\] (.*?) — `([^`]+)`(.*)$")


def load() -> dict[str, list[dict]]:
    """節ごとの項目。項目は checked・title・path・tail（パスの後ろ）・lines（2 行目以降をそのまま）。"""
    out: dict[str, list[dict]] = {TODO: [], DONE: []}
    if not PATH.is_file():
        return out
    section, item = None, None
    for line in PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section, item = line[3:].strip(), None
        elif section in out and (m := ITEM.match(line)):
            item = {"checked": m[1] != " ", "title": m[2], "path": m[3], "tail": m[4], "lines": []}
            out[section].append(item)
        elif item is not None and line.startswith("  "):
            item["lines"].append(line)
    return out


def save(items: dict[str, list[dict]]) -> None:
    def render(it: dict) -> str:
        head = f"- [{'x' if it['checked'] else ' '}] {it['title']} — `{it['path']}`{it['tail']}"
        return "\n".join([head, *it["lines"]])

    parts = [HEADER]
    for name in (TODO, DONE):
        parts.append(f"## {name}\n\n" + ("\n".join(render(it) for it in items[name]) or "なし") + "\n")
    PATH.write_text("\n".join(parts), encoding="utf-8")


def add(entries: list[tuple[str, str, str]]) -> list[str]:
    """(教訓のパス, タイトル, 仕組みの案) を「未対応」に足す。既に載っている教訓は足さない。足したタイトルを返す。"""
    items = load()
    listed = {it["path"] for its in items.values() for it in its}
    added = []
    for path, title, proposal in entries:
        if path in listed:
            continue
        lines = [f"  - 案: {' '.join(proposal.split()) or '（週次で案を書けなかった。Check と Patterns から考える）'}"]
        items[TODO].append(
            {"checked": False, "title": title, "path": path, "tail": "", "lines": [*lines, "  - 仕組み:"]}
        )
        listed.add(path)
        added.append(title)
    if added:
        save(items)
    return added


def mechanism(it: dict) -> str:
    for line in it["lines"]:
        if m := re.match(r"\s*- 仕組み:\s*(.*)", line):
            return m[1].strip()
    return ""


def apply() -> dict:
    """印を付けた「未対応」の項目の教訓を ruled にし、`## Mechanism` に入れた仕組みを書いて「済み」へ移す。"""
    items = load()
    today = str(dt.date.today())
    ruled, errors, keep = [], [], []
    for it in items[TODO]:
        if not it["checked"]:
            keep.append(it)
            continue
        # パスは手で書き換えられうるので、lessons/ の外は触らない
        path = L.inside(it["path"], "lessons")
        if not path or not path.is_file():
            errors.append(f"lessons/ の中の教訓ではない: {it['path']}")
            keep.append(it)
            continue
        meta, body = L.read(path)
        if meta.get("status") != "ruled":
            meta.update(status="ruled", ruled=today)
            body = L.set_section(body, "Mechanism", mechanism(it) or "（記入なし）", before="Evidence")
            L.write(path, meta, body)
        items[DONE].append({**it, "tail": f" (ruled {today})"})
        ruled.append(it["title"])
    if ruled:
        items[TODO] = keep
        save(items)
    return {"ruled": len(ruled), "errors": errors}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", required=True)
    ap.parse_args()
    # lessons:sync から毎回呼ばれるので、移行前の端末では止めずに飛ばす（移行は週次の段階 0 が行う）
    if not L.check_schema(strict=False):
        return 0
    result = apply()
    print(json.dumps(result, ensure_ascii=False))
    for e in result["errors"]:
        print(f"warning: {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
