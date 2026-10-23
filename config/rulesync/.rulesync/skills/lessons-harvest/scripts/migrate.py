"""agent-lessons の教訓・観察を、今の形式（lessonlib.SCHEMA_VERSION）へ移行する。

    python3 migrate.py --check     # 版ごとの件数を出す。移行が要るなら終了コード 1
    python3 migrate.py             # 古い版のファイルを今の版まで順に移行して書き換える

ファイルごとに frontmatter の `schema_version` を見て、MIGRATIONS を版の順に当てる（v0 → v1 → v2 …）。
同じファイルに何度実行しても結果は変わらない。新しい版のファイル（この dotfiles より新しい形式）は触らずに止める。

形式を変えるときの手順:
  1. lessonlib.SCHEMA_VERSION を 1 上げる
  2. MIGRATIONS に「前の版 → 今の版」の関数を足す（meta と本文を受け取り、直したものを返す）
  3. 書き込むスクリプト（write_observations.py・apply_plan.py）と lessons-record skill の雛形を新しい形式にする
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from typing import Callable

import lessonlib as L

Migration = Callable[[dict, str], tuple[dict, str]]


def v0_to_v1(meta: dict, body: str) -> tuple[dict, str]:
    """版を付ける前の形式から v1 へ。観察に date が無ければ、タイトル先頭の日付から足す。"""
    if meta.get("type") == "lesson_observation" and not meta.get("date"):
        m = re.match(r"\d{4}-\d{2}-\d{2}", str(meta.get("title", "")))
        if m:
            meta["date"] = m.group(0)
    return meta, body


# キーは移行元の版。MIGRATIONS[n] は v{n} を v{n+1} にする
MIGRATIONS: dict[int, Migration] = {
    0: v0_to_v1,
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    missing = [v for v in range(L.SCHEMA_VERSION) if v not in MIGRATIONS]
    if missing:
        sys.exit(f"error: MIGRATIONS に v{missing[0]} からの移行が無い")

    files = {p: L.read(p) for p in L.note_files()}
    versions = Counter(L.version_of(meta) for meta, _ in files.values())
    if any(v > L.SCHEMA_VERSION for v in versions):
        sys.exit(f"error: schema_version {L.SCHEMA_VERSION} より新しい形式がある。dotfiles を更新する")

    outdated = {p: mb for p, mb in files.items() if L.version_of(mb[0]) < L.SCHEMA_VERSION}
    summary = {"schema_version": L.SCHEMA_VERSION, "files": {f"v{v}": n for v, n in sorted(versions.items())}}
    if args.check:
        print(json.dumps({**summary, "outdated": len(outdated)}))
        return 1 if outdated else 0

    for path, (meta, body) in outdated.items():
        for v in range(L.version_of(meta), L.SCHEMA_VERSION):
            meta, body = MIGRATIONS[v](meta, body)
        L.write(path, meta, body)
    print(json.dumps({**summary, "migrated": len(outdated)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
