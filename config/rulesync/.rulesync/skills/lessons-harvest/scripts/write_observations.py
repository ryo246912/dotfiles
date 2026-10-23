"""モデルが書いた observations.json を、inbox の観察ノート（type: lesson_observation）にする。

    python3 write_observations.py --work <作業ディレクトリ>

モデルは一般化した文章（rule・why・check）と category・globs だけを書き、source・scope_key・根拠の URL などの
メタデータは candidates.json からこのスクリプトが埋める（モデルの出力を短くし、書き写しの誤りを防ぐ）。

observations.json の書式:

    {
      "observations": [
        {"from": "c001", "category": "doc-behavior-drift", "globs": ["docs/**"],
         "rule": "次に守ること（命令形の 1 文）", "why": "書く時点で防げなかった理由", "check": "push 前に確かめること"},
        {"session": "2026-10-20 dotfiles で ○○ を訂正された", "scope_key": "github.com/o/r", "source": "received", ...}
      ]
    }

`from` は candidates.json の id。セッションでの訂正（PR が無いもの）は `session`・`scope_key`・`source` を書く。
一般化できない候補は書かない（候補から外すだけでよい）。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

import lessonlib as L

REQUIRED = ("category", "rule", "why", "check")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True, type=Path)
    args = ap.parse_args()

    cands = {c["id"]: c for c in json.loads((args.work / "candidates.json").read_text())["candidates"]}
    obs = json.loads((args.work / "observations.json").read_text())["observations"]
    today = str(dt.date.today())
    errors, notes = [], []
    for i, o in enumerate(obs):
        missing = [k for k in REQUIRED if not o.get(k)]
        if "from" in o and o["from"] not in cands:
            missing.append(f"from={o['from']} が candidates.json に無い")
        if "from" not in o and not all(o.get(k) for k in ("session", "scope_key", "source")):
            missing.append("from か session・scope_key・source")
        if missing:
            errors.append(f"observations[{i}]: {', '.join(missing)}")
            continue
        c = cands.get(o.get("from"), {})
        source = c.get("source") or o["source"]
        meta = {
            "title": f"{today} {o['rule']}"[:120],
            "type": "lesson_observation",
            "status": "pending",
            "date": today,
            "source": source,
            "scope_key": c.get("scope_key") or o["scope_key"],
            "category": o["category"],
            "evidence": c.get("evidence") or f"session: {o['session']}",
            "globs": o.get("globs") or [],
        }
        if c.get("reviewer_hash") and source == "team":
            meta["reviewer_hash"] = c["reviewer_hash"]
        body = f"\n## Rule\n{o['rule']}\n\n## Why\n{o['why']}\n\n## Check\n{o['check']}\n"
        slug = re.sub(r"[^\w-]+", "-", o.get("from") or o["category"]).strip("-")
        notes.append((L.LESSONS_DIR / "inbox" / source / f"{today}-{slug}-{i:03d}.md", meta, body))

    # 1 件でも誤りがあれば何も書かない（直して再実行したときに二重に書かないため）
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    for path, meta, body in notes:
        L.write(path, meta, body)
    print(json.dumps({"written": len(notes)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
