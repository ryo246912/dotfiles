"""PR に未 submit（PENDING）のレビューを作る。

指定した行が diff にあるか、同じユーザーの PENDING が既に無いかを先に確かめ、
問題があれば何も投稿せずに終了する。event を付けないので submit はされない。
"""

import argparse
import json
import re
import subprocess
import sys

HUNK_HEADER = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")


def gh_api(*args: str) -> object:
    result = subprocess.run(
        ["gh", "api", *args], check=True, capture_output=True, text=True
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def gh_api_list(path: str) -> list:
    """ページをまたぐ配列を 1 つのリストにまとめて返す。"""
    result = subprocess.run(
        ["gh", "api", path, "--paginate", "--jq", ".[] | tojson"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [json.loads(row) for row in result.stdout.splitlines() if row]


def commentable_lines(patch: str) -> set[int]:
    """patch の RIGHT 側で、コメントを付けられる行番号（追加行と文脈行）を返す。"""
    lines: set[int] = set()
    current = 0
    for row in patch.splitlines():
        header = HUNK_HEADER.match(row)
        if header:
            current = int(header.group(1))
            continue
        if row.startswith("-") or row.startswith("\\"):
            continue
        lines.add(current)
        current += 1
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True, help="owner/name")
    parser.add_argument("--pr", required=True, type=int)
    parser.add_argument("--input", required=True, help="commit_id と comments を持つ JSON")
    parser.add_argument("--dry-run", action="store_true", help="検査だけして投稿しない")
    args = parser.parse_args()

    payload = json.load(open(args.input, encoding="utf-8"))
    base = f"repos/{args.repo}/pulls/{args.pr}"

    head_sha = gh_api(base)["head"]["sha"]
    if payload["commit_id"] != head_sha:
        print(f"commit_id が PR の head ({head_sha}) と違います。行番号を数え直してください")
        return 1

    me = gh_api("user")["login"]
    pending = [
        review
        for review in gh_api_list(f"{base}/reviews")
        if review["state"] == "PENDING" and review["user"]["login"] == me
    ]
    if pending:
        print(f"PENDING のレビューが既にあります: {pending[0]['html_url']}")
        return 1

    files = gh_api_list(f"{base}/files")
    lines_by_path = {f["filename"]: commentable_lines(f.get("patch", "")) for f in files}

    errors = []
    for comment in payload["comments"]:
        path = comment["path"]
        targets = [comment["line"]] + (
            [comment["start_line"]] if "start_line" in comment else []
        )
        if path not in lines_by_path:
            errors.append(f"{path}: PR の変更ファイルにありません")
            continue
        missing = [n for n in targets if n not in lines_by_path[path]]
        if missing:
            errors.append(f"{path}:{missing} は diff の外です")
    if errors:
        print("\n".join(errors))
        return 1

    if args.dry_run:
        print("検査を通りました（--dry-run のため投稿していません）")
        return 0

    body = {
        "commit_id": head_sha,
        "comments": [
            {"side": "RIGHT", **({"start_side": "RIGHT"} if "start_line" in c else {}), **c}
            for c in payload["comments"]
        ],
    }
    result = subprocess.run(
        ["gh", "api", "-X", "POST", f"{base}/reviews", "--input", "-"],
        input=json.dumps(body, ensure_ascii=False),
        check=True,
        capture_output=True,
        text=True,
    )
    review = json.loads(result.stdout)
    print(json.dumps({"id": review["id"], "state": review["state"], "html_url": review["html_url"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
