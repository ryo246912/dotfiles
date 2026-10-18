"""gh stack（GitHub の Stacked PRs）の stack を取得し、PR の情報を付けて JSON で出す。

    python3 get_stack.py --stack 7     # stack 番号で
    python3 get_stack.py --pr 42       # PR 番号で（その PR を含む stack を探す）

Stacks REST API（`repos/{owner}/{repo}/stacks`）を使う。PR が stack に入っていないとき、または repository で
Stacked PRs が有効でないとき（API が 404）は、その PR だけを 1 件の列として返す（is_stack: false）。
出力の prs は下（trunk 側）から上への順。
"""

import argparse
import json
import subprocess
import sys

PR_FIELDS = (
    "number,title,url,state,isDraft,author,baseRefName,headRefName,headRefOid,"
    "additions,deletions,changedFiles"
)


def gh(*args: str) -> object:
    result = subprocess.run(["gh", *args], check=True, capture_output=True, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def stacks_api(path: str) -> object | None:
    """Stacks REST API を呼ぶ。404（stack が無い・機能が無効）なら None を返す。"""
    result = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    if result.returncode != 0:
        if "HTTP 404" in result.stderr:
            return None
        sys.exit(result.stderr.strip())
    return json.loads(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--stack", type=int, help="stack 番号（github.com の stack の UI に出る番号）")
    target.add_argument("--pr", type=int, help="PR 番号")
    parser.add_argument("--repo", help="owner/name（省略時はカレントディレクトリのリポジトリ）")
    args = parser.parse_args()

    repo = args.repo or gh("repo", "view", "--json", "nameWithOwner")["nameWithOwner"]
    warnings: list[str] = []

    if args.stack is not None:
        stack = stacks_api(f"repos/{repo}/stacks/{args.stack}")
        if stack is None:
            sys.exit(f"stack #{args.stack} が見つからない（Stacked PRs が無効な repository かもしれない）")
    else:
        found = stacks_api(f"repos/{repo}/stacks?pull_request={args.pr}")
        stack = found[0] if found else None
        if found is None:
            warnings.append("Stacks API が 404 を返した（Stacked PRs が無効）。PR 単体として扱う")

    numbers = [entry["number"] for entry in stack["pull_requests"]] if stack else [args.pr]
    prs = [gh("pr", "view", str(number), "--repo", repo, "--json", PR_FIELDS) for number in numbers]

    # 全体の差分は、まだ merge されていない一番下の PR の base から、一番上の PR の head まで
    unmerged = [pr for pr in prs if pr["state"] != "MERGED"]
    bottom = unmerged[0] if unmerged else prs[0]
    top = prs[-1]
    if stack and not unmerged:
        warnings.append("stack の PR はすべて merge 済み")

    json.dump(
        {
            "repo": repo,
            "is_stack": stack is not None,
            "stack_number": stack["number"] if stack else None,
            "stack_url": stack.get("url") if stack else None,
            "trunk": stack["base"]["ref"] if stack else bottom["baseRefName"],
            "input": {"stack": args.stack} if args.stack is not None else {"pr": args.pr},
            "diff_base": bottom["baseRefName"],
            "top_pr": top["number"],
            "top_head_sha": top["headRefOid"],
            "prs": prs,
            "warnings": warnings,
        },
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
