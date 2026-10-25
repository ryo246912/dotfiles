"""モデルが書いた観察（JSON）を、inbox の観察ノート（type: lesson_observation）にする。

    python3 write_observations.py --work <作業ディレクトリ> --batch 001        # batches/001.json の候補から書いたもの
    python3 write_observations.py --work <作業ディレクトリ> --batch sessions   # セッションでの訂正から書いたもの

`<work>/observations/<batch>.json` を読み、成功したら `<work>/observations/<batch>.done` を置く（全バッチが済んだかを
apply_plan.py が確かめるため。済んでいないバッチがあると前回の実行日を進めない）。

モデルは一般化した文章（rule・pattern・why・check）と category・globs だけを書き、source・scope_key・根拠の URL などの
メタデータは candidates.json からこのスクリプトが埋める（モデルの出力を短くし、書き写しの誤りを防ぐ）。

`observations/<batch>.json` の書式:

    {
      "observations": [
        {"from": "c0001", "category": "shell-error-masking", "globs": ["**/*.sh"],
         "rule": "仕組みの単位で次に守ること（命令形の 1 文）",
         "pattern": "`x=$(a | b)` で a の失敗が消える → 先に変数へ受けてから加工する",
         "why": "書く時点で防げなかった理由", "check": "diff で何を探すか（`$(` の中の `|` など）"},
        {"session": "2026-10-20 dotfiles で ○○ を訂正された", "scope_key": "github.com/o/r", "source": "received", ...}
      ]
    }

`from` はそのバッチの候補の id。セッションでの訂正（PR が無いもの）は `--batch sessions` で、`session`・`scope_key`・
`source` を書く。一般化できない候補は書かない（候補から外すだけでよい）。1 件も書かないバッチも `{"observations": []}` を書く。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

import lessonlib as L

REQUIRED = ("category", "rule", "pattern", "why", "check")


def free_path(path: Path) -> Path:
    # 候補の id は実行ごとの連番なので、同じ日の 2 周目では別の指摘が同じ名前になる。前回の観察を上書きしない
    out, n = path, 2
    while out.exists():
        out, n = path.with_stem(f"{path.stem}-{n}"), n + 1
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True, type=Path)
    ap.add_argument("--batch", required=True, help="001 などのバッチ番号か sessions")
    args = ap.parse_args()
    L.check_schema(strict=True)
    if not re.fullmatch(r"\d{3}|sessions", args.batch):
        print(f"--batch が不正: {args.batch}", file=sys.stderr)
        return 1

    done = args.work / "observations" / f"{args.batch}.done"
    if done.is_file():
        print(f"バッチ {args.batch} は書き出し済み（二重に書かないため止める）", file=sys.stderr)
        return 1
    cands = {}
    if args.batch != "sessions":
        ids = {c["id"] for c in json.loads((args.work / "batches" / f"{args.batch}.json").read_text())["candidates"]}
        cands = {
            c["id"]: c for c in json.loads((args.work / "candidates.json").read_text())["candidates"] if c["id"] in ids
        }
    obs = json.loads((args.work / "observations" / f"{args.batch}.json").read_text())["observations"]
    today = str(dt.date.today())
    errors, notes = [], []
    for i, o in enumerate(obs):
        missing = [k for k in REQUIRED if not o.get(k)]
        if "from" in o and o["from"] not in cands:
            missing.append(f"from={o['from']} がバッチ {args.batch} に無い")
        if "from" not in o and not all(o.get(k) for k in ("session", "scope_key", "source")):
            missing.append("from か session・scope_key・source")
        missing += [
            f"{k} は日本語で書く（{e}）" for k in (*REQUIRED[1:], "session") if (e := L.language_error(o.get(k, "")))
        ]
        if missing:
            errors.append(f"observations[{i}]: {', '.join(missing)}")
            continue
        c = cands.get(o.get("from"), {})
        source = c.get("source") or o["source"]
        scope_key = c.get("scope_key") or o["scope_key"]
        # source と scope_key はファイルの置き場所になるので、決まった形だけを通す（inbox の外へ書かないため）
        if source not in L.SOURCES or not L.SCOPE_KEY.fullmatch(scope_key):
            errors.append(f"observations[{i}]: source か scope_key が不正: {source} / {scope_key}")
            continue
        meta = {
            "title": f"{today} {o['rule']}",
            "type": "lesson_observation",
            "status": "pending",
            "date": today,
            "source": source,
            "scope_key": scope_key,
            "category": o["category"],
            "evidence": c.get("evidence") or f"session: {o['session']}",
            "globs": L.normalize_globs(o.get("globs")),
        }
        if c.get("reviewer_hash") and source == "team":
            meta["reviewer_hash"] = c["reviewer_hash"]
        pattern = re.sub(r"^-\s*", "", " ".join(str(o["pattern"]).split()))
        body = f"\n## Rule\n{o['rule']}\n\n## Patterns\n- {pattern}\n\n## Why\n{o['why']}\n\n## Check\n{o['check']}\n"
        slug = re.sub(r"[^\w-]+", "-", o.get("from") or o["category"]).strip("-")
        notes.append((L.LESSONS_DIR / "inbox" / source / f"{today}-{slug}-{args.batch}-{i:03d}.md", meta, body))

    # 1 件でも誤りがあれば何も書かない（直して再実行したときに二重に書かないため）
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    for path, meta, body in notes:
        L.write(free_path(path), meta, body)
    done.touch()
    print(json.dumps({"batch": args.batch, "written": len(notes)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
