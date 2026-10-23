"""agent-lessons の教訓を絞り込んで、必要な項目だけを JSON で出す。

    python3 lessons_query.py --source received,team --paths $(git diff --name-only "$base"...HEAD)
    python3 lessons_query.py --source given,team --full
    python3 lessons_query.py --index                      # 全教訓の一覧（集計の段階で使う）

Basic Memory を 1 件ずつ read-note するとトークンも時間もかかるため、clone の Markdown を直接読む。
既定ではカレントディレクトリの `origin` から scope_key（global・owner・repo）を決め、active な教訓だけを出す。

  --source   received / given / team をカンマ区切りで（既定はすべて）
  --paths    変更ファイル。教訓の globs が空か、どれかに一致するものだけ残す
  --full     Rule・Check まで出す（既定はタイトルと場所だけ）
  --index    scope・status で絞らず、全教訓を集計用の項目（件数など）付きで出す
"""

from __future__ import annotations

import argparse
import json
import sys

import lessonlib as L


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="received,given,team")
    ap.add_argument("--paths", nargs="*", default=[])
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--index", action="store_true")
    args = ap.parse_args()
    L.check_schema(strict=False)

    sources = set(args.source.split(","))
    keys = set(L.scope_keys())
    out = []
    for path in L.lesson_files():
        meta, body = L.read(path)
        if meta.get("type") != "lesson" or meta.get("source") not in sources:
            continue
        rel = str(path.relative_to(L.LESSONS_DIR))
        if args.index:
            out.append(
                {
                    "path": rel,
                    "title": meta.get("title"),
                    "status": meta.get("status"),
                    "source": meta.get("source"),
                    "scope_key": meta.get("scope_key"),
                    "category": meta.get("category"),
                    **{k: meta.get(k) for k in ("count", "prs", "sessions", "reviewers", "last_seen") if k in meta},
                }
            )
            continue
        if meta.get("status") != "active" or meta.get("scope_key") not in keys:
            continue
        if not L.matches(meta.get("globs"), args.paths):
            continue
        item = {"path": rel, "title": meta.get("title"), "source": meta.get("source")}
        if args.full:
            sec = L.sections(body)
            item["rule"] = sec.get("Rule", "")
            item["check"] = sec.get("Check", "")
        out.append(item)

    json.dump(out, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
