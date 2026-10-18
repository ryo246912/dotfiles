"""PR が属する stack（base / head ブランチが連なった PR の列）を調べて JSON で出す。

PR の base が別の PR の head なら下へ、PR の head を base にする PR があれば上へ辿る。
出力の prs は下（default branch 側）から上への順。
"""

import argparse
import json
import subprocess
import sys

PR_FIELDS = (
    "number,title,url,state,author,baseRefName,headRefName,headRefOid,"
    "additions,deletions,changedFiles"
)


def gh(*args: str) -> object:
    result = subprocess.run(["gh", *args], check=True, capture_output=True, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def view_pr(repo: str, number: int) -> dict:
    return gh("pr", "view", str(number), "--repo", repo, "--json", PR_FIELDS)


def list_prs(repo: str, *filters: str) -> list[dict]:
    return gh(
        "pr", "list", "--repo", repo, "--state", "all", "--limit", "20",
        "--json", PR_FIELDS, *filters,
    )


def pick(prs: list[dict]) -> dict | None:
    """同じブランチの PR が複数あれば、open を優先し、その中で新しいものを選ぶ。"""
    rank = {"OPEN": 0, "MERGED": 1, "CLOSED": 2}
    candidates = [pr for pr in prs if pr["state"] != "CLOSED"]
    if not candidates:
        return None
    return sorted(candidates, key=lambda pr: (rank[pr["state"]], -pr["number"]))[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pr", type=int, required=True)
    parser.add_argument("--repo", help="owner/name（省略時はカレントディレクトリのリポジトリ）")
    args = parser.parse_args()

    repo = args.repo or gh("repo", "view", "--json", "nameWithOwner")["nameWithOwner"]
    default_branch = gh("repo", "view", repo, "--json", "defaultBranchRef")[
        "defaultBranchRef"
    ]["name"]

    target = view_pr(repo, args.pr)
    warnings: list[str] = []

    # 下へ: base が default branch になるか、base を head にする PR が無くなるまで辿る
    below: list[dict] = []
    current = target
    while current["baseRefName"] != default_branch:
        parent = pick(list_prs(repo, "--head", current["baseRefName"]))
        if parent is None or any(pr["number"] == parent["number"] for pr in below):
            break
        below.insert(0, parent)
        if parent["state"] == "MERGED":
            break
        current = parent

    # 上へ: head を base にする open な PR を辿る。分岐していたら止めて警告する
    above: list[dict] = []
    current = target
    while True:
        children = [
            pr for pr in list_prs(repo, "--base", current["headRefName"])
            if pr["state"] == "OPEN"
        ]
        if not children:
            break
        if len(children) > 1:
            numbers = ", ".join(f"#{pr['number']}" for pr in children)
            warnings.append(f"#{current['number']} の上で分岐している: {numbers}")
            break
        child = children[0]
        if any(pr["number"] == child["number"] for pr in above):
            break
        above.append(child)
        current = child

    prs = below + [target] + above
    unmerged = [pr for pr in prs if pr["state"] != "MERGED"]
    bottom = unmerged[0] if unmerged else target
    top = prs[-1]
    if bottom["baseRefName"] != default_branch and not any(
        pr["headRefName"] == bottom["baseRefName"] for pr in prs
    ):
        warnings.append(
            f"一番下の PR の base `{bottom['baseRefName']}` は default branch でも stack 内の PR でもない"
        )

    json.dump(
        {
            "repo": repo,
            "default_branch": default_branch,
            "input_pr": target["number"],
            "is_stack": len(prs) > 1,
            # 全体の差分は stack_base...top_head_sha で取る
            "stack_base": bottom["baseRefName"],
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
