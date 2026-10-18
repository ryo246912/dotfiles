"""自分にレビュー依頼が来た PR を監視し、資料を作るべきものが出たら JSON で出して終了する。

    python3 watch_prs.py                 # 対象が出るまで待つ（最長 --max-wait 秒）
    python3 watch_prs.py --once          # 1 回だけ確認する
    python3 watch_prs.py --notify "本文" # mac の通知を出すだけ

カレントディレクトリのリポジトリの open な PR のうち、次をすべて満たすものを対象にする。

- 自分にレビュー依頼が来ている（review-requested:@me）。draft ではない。自分が作った PR ではない
- 最後のコミットから --settle 秒経っている（push の連発が落ち着くのを待つ）
- まだ資料を作っていないか、前回作ったあとに再レビュー依頼が来た

gh stack の stack に入っている PR は stack 単位にまとめ、1 件として扱う。追加と削除の行数の合計が --max-lines を
超えるものは、資料を作らず large として出す。見つけたものは状態ファイルに記録し、二度は出さない。
待っている間は gh を呼ぶだけで、勤務時間外（--hours・--weekdays の外）は確認しない。

出力（標準出力の最後の 1 行）:

    {"targets": [{"key": "stack-7", "arg": "stack 7", "prs": [41, 42], ...}], "large": [...]}

対象が無いまま --max-wait を過ぎたら {"targets": [], "large": []} を出して終了する。
"""

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

STATE_PATH = Path("plan/.pr-reviewer-brief/watch-state.json")


def gh_json(*args: str) -> object:
    result = subprocess.run(["gh", *args], check=True, capture_output=True, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def gh_api_optional(path: str) -> object | None:
    result = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    return json.loads(result.stdout) if result.returncode == 0 and result.stdout.strip() else None


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def last_review_request(repo: str, number: int, me: str) -> str:
    """自分へのレビュー依頼のうち、いちばん新しいものの時刻を返す。"""
    query = f'.[] | select(.event == "review_requested" and .requested_reviewer.login == "{me}") | .created_at'
    result = subprocess.run(
        ["gh", "api", "--paginate", f"repos/{repo}/issues/{number}/timeline", "--jq", query],
        check=True,
        capture_output=True,
        text=True,
    )
    return max(result.stdout.split(), default="")


def in_working_hours(hours: str, weekdays: str) -> bool:
    now = dt.datetime.now()
    start, end = (int(h) for h in hours.split("-"))
    days = {int(d) for d in weekdays.split(",")}
    return now.isoweekday() in days and start <= now.hour < end


def scan(repo: str, me: str, state: dict, settle: int, max_lines: int) -> tuple[list, list]:
    prs = gh_json(
        "pr", "list", "--repo", repo, "--search", "review-requested:@me draft:false", "--limit", "50",
        "--json", "number,title,author,isDraft,headRefOid,additions,deletions,commits",
    )
    now = dt.datetime.now(dt.timezone.utc)
    groups: dict[str, dict] = {}
    for pr in prs:
        if pr["isDraft"] or pr["author"]["login"] == me:
            continue
        stacks = gh_api_optional(f"repos/{repo}/stacks?pull_request={pr['number']}")
        stack = stacks[0] if stacks else None
        key = f"stack-{stack['number']}" if stack else f"pr-{pr['number']}"
        group = groups.setdefault(
            key,
            {
                "key": key,
                "arg": f"stack {stack['number']}" if stack else str(pr["number"]),
                "prs": [],
                "lines": 0,
                "requested_at": "",
                "last_commit_at": "",
            },
        )
        group["prs"].append(pr["number"])
        group["lines"] += pr["additions"] + pr["deletions"]
        committed = pr["commits"][-1]["committedDate"] if pr["commits"] else ""
        group["last_commit_at"] = max(group["last_commit_at"], committed)
        group["requested_at"] = max(group["requested_at"], last_review_request(repo, pr["number"], me))

    targets, large = [], []
    for group in groups.values():
        done = state.get(group["key"])
        if done and done["requested_at"] >= group["requested_at"]:
            continue
        if group["last_commit_at"] and (now - parse_time(group["last_commit_at"])).total_seconds() < settle:
            continue
        (large if group["lines"] > max_lines else targets).append(group)
    return targets, large


def notify(message: str) -> None:
    if shutil.which("osascript"):
        script = f"display notification {json.dumps(message)} with title \"pr-reviewer-brief\""
        subprocess.run(["osascript", "-e", script], check=False)
    elif shutil.which("notify-send"):
        subprocess.run(["notify-send", "pr-reviewer-brief", message], check=False)
    print(message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--interval", type=int, default=600, help="確認の間隔（秒）")
    parser.add_argument("--max-wait", type=int, default=6600, help="対象が無いまま待つ最長時間（秒）")
    parser.add_argument("--settle", type=int, default=900, help="最後のコミットから待つ時間（秒）")
    parser.add_argument("--max-lines", type=int, default=3000, help="これを超える PR は資料を作らない")
    parser.add_argument("--hours", default="9-20", help="確認する時間帯（時、開始-終了）")
    parser.add_argument("--weekdays", default="1,2,3,4,5", help="確認する曜日（1=月 … 7=日）")
    parser.add_argument("--once", action="store_true", help="1 回だけ確認して終了する")
    parser.add_argument("--notify", metavar="MESSAGE", help="通知を出すだけで終了する")
    args = parser.parse_args()

    if args.notify:
        notify(args.notify)
        return 0

    repo = gh_json("repo", "view", "--json", "nameWithOwner")["nameWithOwner"]
    me = gh_json("api", "user")["login"]
    state = json.loads(STATE_PATH.read_text()) if STATE_PATH.exists() else {}
    deadline = time.monotonic() + args.max_wait

    while True:
        targets, large = ([], [])
        if args.once or in_working_hours(args.hours, args.weekdays):
            targets, large = scan(repo, me, state, args.settle, args.max_lines)
        if targets or large or args.once or time.monotonic() >= deadline:
            break
        time.sleep(min(args.interval, max(1, deadline - time.monotonic())))

    # 出したものは記録し、次からは出さない（作り直すのは再レビュー依頼が来たときだけ）
    for group in targets + large:
        state[group["key"]] = {"requested_at": group["requested_at"], "found_at": dt.datetime.now().isoformat()}
    if targets or large:
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"repo": repo, "targets": targets, "large": large}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
