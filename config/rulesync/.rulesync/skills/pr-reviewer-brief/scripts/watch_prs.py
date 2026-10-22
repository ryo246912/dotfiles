"""新しく作られた PR を監視し、資料を作るべきものが出たら JSON で出して終了する。

    python3 watch_prs.py                 # 対象が出るまで待つ（最長 --max-wait 秒）
    python3 watch_prs.py --once          # 1 回だけ確認する
    python3 watch_prs.py --notify "本文" # mac の通知を出すだけ

カレントディレクトリのリポジトリの open な PR のうち、まだ見ていないもの（draft と自分が作ったものは除く）を
対象にする。資料は PR ごとに最初の 1 回だけ作る想定で、出した PR は状態ファイルに記録し、二度は出さない。
gh stack の stack に入っている PR は stack 単位にまとめ、stack ごとに 1 回だけ出す。

状態ファイルが無い初回は、その時点で open な PR をすべて「見た」として記録するだけで、何も出さない
（監視を始める前からある PR の資料をまとめて作らないため）。待っている間は gh を呼ぶだけで、
勤務時間外（--hours・--weekdays の外）は確認しない。

出力（標準出力の最後の 1 行）:

    {"repo": "owner/name", "targets": [{"key": "stack-7", "arg": "stack 7", "prs": [41, 42]}]}

対象が無いまま --max-wait を過ぎたら targets を空にして終了する。
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


def in_working_hours(hours: str, weekdays: str) -> bool:
    now = dt.datetime.now()
    start, end = (int(h) for h in hours.split("-"))
    days = {int(d) for d in weekdays.split(",")}
    return now.isoweekday() in days and start <= now.hour < end


def open_prs(repo: str, me: str) -> list[dict]:
    prs = gh_json("pr", "list", "--repo", repo, "--state", "open", "--limit", "1000",
                  "--json", "number,author,isDraft")
    return [pr for pr in prs if not pr["isDraft"] and pr["author"]["login"] != me]


def scan(repo: str, me: str, state: dict) -> list[dict]:
    seen = set(state["seen"])
    groups: dict[str, dict] = {}
    for pr in open_prs(repo, me):
        if pr["number"] in seen:
            continue
        stacks = gh_api_optional(f"repos/{repo}/stacks?pull_request={pr['number']}")
        stack = stacks[0] if stacks else None
        key = f"stack-{stack['number']}" if stack else f"pr-{pr['number']}"
        arg = f"stack {stack['number']}" if stack else str(pr["number"])
        groups.setdefault(key, {"key": key, "arg": arg, "prs": []})["prs"].append(pr["number"])

    targets = []
    for group in groups.values():
        state["seen"].extend(group["prs"])
        # stack に後から PR が足されても、その stack の資料は作り直さない
        if group["key"] not in state["done"]:
            state["done"].append(group["key"])
            targets.append(group)
    return targets


def notify(message: str) -> None:
    if shutil.which("osascript"):
        script = f"display notification {json.dumps(message)} with title \"pr-reviewer-brief\""
        subprocess.run(["osascript", "-e", script], check=False)
    elif shutil.which("notify-send"):
        subprocess.run(["notify-send", "pr-reviewer-brief", message], check=False)
    print(message)


def save(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--interval", type=int, default=600, help="確認の間隔（秒）")
    parser.add_argument("--max-wait", type=int, default=6600, help="対象が無いまま待つ最長時間（秒）")
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

    if not STATE_PATH.exists():
        existing = [pr["number"] for pr in open_prs(repo, me)]
        save({"seen": existing, "done": []})
        print(f"監視を始めた。既存の open な PR {len(existing)} 件は対象にしない", file=sys.stderr)
    state = json.loads(STATE_PATH.read_text())
    deadline = time.monotonic() + args.max_wait

    while True:
        targets = []
        if args.once or in_working_hours(args.hours, args.weekdays):
            targets = scan(repo, me, state)
        if targets or args.once or time.monotonic() >= deadline:
            break
        time.sleep(min(args.interval, max(1, deadline - time.monotonic())))

    save(state)
    print(json.dumps({"repo": repo, "targets": targets}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
