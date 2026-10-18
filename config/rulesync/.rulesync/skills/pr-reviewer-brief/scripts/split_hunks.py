"""unified diff を hunk に分け、ID（h001 など）を振った JSON にする。

    git diff origin/main...FETCH_HEAD | python3 split_hunks.py --out hunks.json --index

--index を付けると、hunk ごとに 1 行の一覧（ID・ファイル・行範囲・増減・最初の変更行）を標準出力に出す。
変更グループへの振り分けは、この一覧を見て行う。hunk の無いファイル（バイナリ・改名だけ・モード変更だけ）も
1 件の hunk として ID を振る。
"""

import argparse
import json
import re
import sys
from pathlib import Path

HUNK_HEADER = re.compile(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$")
DIFF_GIT = re.compile(r"^diff --git a/(.*) b/(.*)$")


def parse(diff: str) -> list[dict]:
    files: list[dict] = []
    current: dict | None = None
    hunk: dict | None = None
    old_no = new_no = 0

    for row in diff.splitlines():
        match = DIFF_GIT.match(row)
        if match:
            current = {"old_path": match.group(1), "path": match.group(2), "status": "modified", "hunks": []}
            files.append(current)
            hunk = None
            continue
        if current is None:
            continue
        if hunk is None:
            if row.startswith("new file mode"):
                current["status"] = "added"
            elif row.startswith("deleted file mode"):
                current["status"] = "deleted"
            elif row.startswith("rename from "):
                current["status"] = "renamed"
            elif row.startswith("Binary files "):
                current["status"] = "binary" if current["status"] == "modified" else current["status"]
                current["binary"] = True
        match = HUNK_HEADER.match(row)
        if match:
            old_no, new_no = int(match.group(1)), int(match.group(2))
            hunk = {"header": row, "context": match.group(3).strip(), "new_start": new_no, "lines": []}
            current["hunks"].append(hunk)
            continue
        if hunk is None:
            continue
        sign, text = row[:1], row[1:]
        if sign == "+":
            hunk["lines"].append(["+", None, new_no, text])
            new_no += 1
        elif sign == "-":
            hunk["lines"].append(["-", old_no, None, text])
            old_no += 1
        elif sign == " " or row == "":
            hunk["lines"].append([" ", old_no, new_no, text])
            old_no += 1
            new_no += 1
        elif sign == "\\":
            hunk["lines"].append(["\\", None, None, text.strip()])

    hunks: list[dict] = []
    for file in files:
        entries = file["hunks"] or [{"header": f"({file['status']})", "context": "", "new_start": 1, "lines": []}]
        for entry in entries:
            hunks.append(
                {
                    "id": f"h{len(hunks) + 1:03d}",
                    "path": file["path"],
                    "old_path": file["old_path"],
                    "status": file["status"],
                    **entry,
                    "added": sum(1 for line in entry["lines"] if line[0] == "+"),
                    "removed": sum(1 for line in entry["lines"] if line[0] == "-"),
                }
            )
    return hunks


def index_line(hunk: dict) -> str:
    first = next((line[3].strip() for line in hunk["lines"] if line[0] in "+-" and line[3].strip()), "")
    path = hunk["path"] if hunk["old_path"] == hunk["path"] else f"{hunk['old_path']} -> {hunk['path']}"
    head = hunk["header"].split(" @@")[0] + " @@" if hunk["lines"] else hunk["header"]
    return f"{hunk['id']} {path} {head} +{hunk['added']} -{hunk['removed']} | {first[:100]}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("diff", nargs="?", type=Path, help="diff のファイル（省略時は標準入力）")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--index", action="store_true", help="hunk の一覧を標準出力に出す")
    args = parser.parse_args()

    diff = args.diff.read_text() if args.diff else sys.stdin.read()
    hunks = parse(diff)
    args.out.write_text(json.dumps({"hunks": hunks}, ensure_ascii=False) + "\n")

    files = len({hunk["path"] for hunk in hunks})
    added = sum(hunk["added"] for hunk in hunks)
    removed = sum(hunk["removed"] for hunk in hunks)
    print(f"{files} files / {len(hunks)} hunks +{added} -{removed}", file=sys.stderr)
    if args.index:
        for hunk in hunks:
            print(index_line(hunk))
    return 0


if __name__ == "__main__":
    sys.exit(main())
