"""targets のリポジトリから、前回以降にマージされた PR の「採用されたレビュー指摘」を集めて候補にする。

    python3 collect.py --work <作業ディレクトリ>

`~/.config/agent-lessons/targets.yml` と `targets.*.yml` を読み、`harvest-state.yml` の日付（無ければ 90 日前）
から今日までにマージされた PR のレビュースレッドを取る。指摘者と PR の作者から source（received / given / team）を
決め、採用されたものだけを、本文を短く削って `<work>/candidates.json` に書く。既に記録済みの指摘（inbox・lessons の
根拠にある URL）は除く。モデルが読むのはこの JSON だけにして、GitHub の生の応答をコンテキストに入れない。

最後に 1 行の要約（JSON）を stdout に出す。
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import lessonlib as L

PR_LIMIT = 1000
DEFAULT_DAYS = 90
MAX_COMMENTS = 100
BODY_CHARS = 500
REPLY_CHARS = 200

REJECT = re.compile(
    r"対応しません|対応しない|見送|不要です|意図(どおり|通り)|仕様です|won't fix|wontfix|not (going to|gonna) fix|by design|intended",
    re.I,
)
ADOPT = re.compile(r"修正しました|対応しました|直しました|反映しました|\bfixed\b|\bdone\b|\baddressed\b", re.I)
NOT_YET = re.compile(r"まだ|未対応|後で|あとで|別の? ?PR|not yet|later|follow-?up", re.I)
ADDRESSED_MARK = re.compile(r"Addressed in", re.I)  # bot が修正 commit を確かめたときに付ける印

QUERY = """
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      author { login }
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          resolvedBy { login }
          path
          comments(first: 100) {
            totalCount
            nodes { author { login __typename } body url }
          }
        }
      }
    }
  }
}
"""


def gh(*args: str) -> object:
    out = subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else None


def read_targets() -> list[tuple[str, dict]]:
    """targets*.yml を読む。書式は `repos:` の下に `- repo: <host>/<owner>/<repo>` と任意の `team: true`。"""
    files = [L.TARGETS_DIR / "targets.yml", *sorted(L.TARGETS_DIR.glob("targets.*.yml"))]
    result = []
    for f in files:
        if not f.is_file():
            continue
        repos, cur = [], None
        for line in f.read_text(encoding="utf-8").splitlines():
            s = line.split("#", 1)[0].strip()
            if s.startswith("- repo:"):
                cur = {"repo": s.split(":", 1)[1].strip(), "team": False}
                repos.append(cur)
            elif s.startswith("team:") and cur is not None:
                cur["team"] = s.split(":", 1)[1].strip() == "true"
        result.append((f.name, {"repos": repos}))
    return result


def read_state() -> dict[str, str]:
    path = L.LESSONS_DIR / "harvest-state.yml"
    if not path.is_file():
        return {}
    state = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        k, _, v = line.split("#", 1)[0].partition(":")
        if v.strip():
            state[k.strip()] = v.strip()
    return state


def known_evidence() -> set[str]:
    urls: set[str] = set()
    for sub in ("inbox", "lessons"):
        for p in (L.LESSONS_DIR / sub).rglob("*.md"):
            urls.update(re.findall(r"https?://\S+?#discussion_r\d+", p.read_text(encoding="utf-8")))
    return urls


def list_prs(host: str, repo: str, since: dt.date, until: dt.date, qualifier: str) -> list[dict]:
    """期間内にマージされた PR。上限に当たったら期間を半分に分けて取り直す。"""
    search = f"merged:{since}..{until} {qualifier}".strip()
    prs = gh("pr", "list", "-R", f"{host}/{repo}", "--state", "merged", "--search", search,
             "--limit", str(PR_LIMIT), "--json", "number,author,url")  # fmt: skip
    if len(prs) < PR_LIMIT or since >= until:
        if len(prs) >= PR_LIMIT:
            print(f"warning: {repo} {since} で {PR_LIMIT} 件を超えた。残りは取れていない", file=sys.stderr)
        return prs
    mid = since + (until - since) // 2
    return list_prs(host, repo, since, mid, qualifier) + list_prs(
        host, repo, mid + dt.timedelta(days=1), until, qualifier
    )


def threads(host: str, owner: str, name: str, number: int) -> tuple[str, list[dict]]:
    pages = gh("api", "graphql", "--hostname", host, "--paginate", "--slurp",
               "-F", f"owner={owner}", "-F", f"name={name}", "-F", f"number={number}", "-f", f"query={QUERY}")  # fmt: skip
    author = pages[0]["data"]["repository"]["pullRequest"]["author"]["login"]
    nodes = [n for p in pages for n in p["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]]
    return author, nodes


def trim(body: str, limit: int) -> str:
    """bot の定型部分（折りたたみ・HTML・AI 向けの指示文）を落として短くする。"""
    body = re.sub(r"<details>.*?</details>", "", body, flags=re.S)
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    body = re.sub(r"<(a|picture)\b.*?</\1>", "", body, flags=re.S)
    body = re.sub(r"<[^>]+>|!\[[^\]]*\]\([^)]*\)", "", body)
    body = re.sub(r"\s+", " ", body).strip()
    return body[:limit] + ("…" if len(body) > limit else "")


def classify(me: str, pr_author: str, reviewer: str, team: bool) -> str | None:
    if pr_author == me and reviewer != me:
        return "received"
    if reviewer == me and pr_author != me:
        return "given"
    if team and me not in (pr_author, reviewer):
        return "team"
    return None


def adopted(thread: dict, pr_author: str) -> bool:
    """PR の作者が受け入れたと読めるものだけを採用とみなす。

    コメントした行が変わっただけ（isOutdated）や、作者以外の「fixed?」のような返信では採用としない。
    採用とみなすのは、作者が却下していないうえで、次のどれかがあるとき:
      - bot が修正 commit を確かめた印（Addressed in）がある
      - 作者が「修正しました」などと返信している（「まだ」「別 PR で」などを含む返信は除く）
      - 作者か指摘者がスレッドを resolve した
    """
    comments = thread["comments"]["nodes"]
    first, replies = comments[0], comments[1:]
    reviewer = (first["author"] or {}).get("login")
    by_author = [r["body"] for r in replies if (r["author"] or {}).get("login") == pr_author]
    if any(REJECT.search(b) for b in by_author):
        return False
    if any(ADDRESSED_MARK.search(c["body"]) for c in comments):
        return True
    if any(ADOPT.search(b) and not NOT_YET.search(b) for b in by_author):
        return True
    resolver = (thread.get("resolvedBy") or {}).get("login")
    return bool(thread["isResolved"]) and resolver in (pr_author, reviewer)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True, type=Path)
    args = ap.parse_args()
    L.check_schema(strict=False)
    args.work.mkdir(parents=True, exist_ok=True)

    today = dt.date.today()
    state = read_state()
    seen = known_evidence()
    logins: dict[str, str] = {}
    personal: list[str] = []
    candidates: list[dict] = []
    targets_read: dict[str, str] = {}

    for fname, conf in read_targets():
        since = dt.date.fromisoformat(state[fname]) if fname in state else today - dt.timedelta(days=DEFAULT_DAYS)
        targets_read[fname] = str(since)
        for t in conf["repos"]:
            host, owner, name = t["repo"].split("/")
            if fname == "targets.yml":
                personal.append(t["repo"])
            if host not in logins:
                logins[host] = gh("api", "user", "--hostname", host)["login"]
            me = logins[host]
            quals = [""] if t["team"] else ["author:@me", "reviewed-by:@me"]
            numbers = {p["number"] for q in quals for p in list_prs(host, f"{owner}/{name}", since, today, q)}
            for number in sorted(numbers):
                pr_author, nodes = threads(host, owner, name, number)
                for th in nodes:
                    comments = th["comments"]
                    if comments["totalCount"] > MAX_COMMENTS or not comments["nodes"]:
                        continue
                    first = comments["nodes"][0]
                    reviewer = (first["author"] or {}).get("login", "")
                    source = classify(me, pr_author, reviewer, t["team"])
                    if not source or first["url"] in seen or not adopted(th, pr_author):
                        continue
                    last = comments["nodes"][-1] if len(comments["nodes"]) > 1 else None
                    candidates.append(
                        {
                            "id": f"c{len(candidates) + 1:03d}",
                            "source": source,
                            "scope_key": t["repo"],
                            "targets_file": fname,
                            "evidence": first["url"],
                            "path": th["path"],
                            "reviewer": "bot" if (first["author"] or {}).get("__typename") == "Bot" else "user",
                            "reviewer_hash": hashlib.sha1(f"{host}/{reviewer}".encode()).hexdigest()[:8],
                            "comment": trim(first["body"], BODY_CHARS),
                            "last_reply": trim(last["body"], REPLY_CHARS) if last else "",
                        }
                    )

    result = {"until": str(today), "targets": targets_read, "personal_repos": personal, "candidates": candidates}
    (args.work / "candidates.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    by_source: dict[str, int] = {}
    for c in candidates:
        by_source[c["source"]] = by_source.get(c["source"], 0) + 1
    print(
        json.dumps({"candidates": len(candidates), "by_source": by_source, "targets": targets_read}, ensure_ascii=False)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
