"""targets のリポジトリから、前回以降にマージされた PR のレビュー指摘を集めて候補にする。

    python3 collect.py --work <作業ディレクトリ>

`~/.config/agent-lessons/targets.yml` と `targets.*.yml` を読み、`harvest-state.yml` の日付（無ければ 90 日前）
から今日までにマージされた PR の、レビュースレッド・レビュー本文・会話タブのコメントを取る（bot のものも含む）。
指摘者と PR の作者から source（received / given / team）を決め、本文を短く削って `<work>/candidates.json` に書く。
除くのは、PR の作者がスレッドで却下した指摘（「対応しません」「仕様です」など）、作者自身のレビュー本文・会話タブの
コメント、既に記録済みの指摘（inbox・lessons の根拠にある URL）。どれを教訓にするかは段階 1 のモデルが決める。

- 1 回に集める候補は targets ファイルごとに MAX_CANDIDATES 件まで。PR をマージ日の古い順に日単位で処理し、上限に
  達したら残りの日は次回に回す（`next` に次回の開始日を書く。初回や久しぶりの実行で大量に溜まっていても溢れない）
- モデルには `<work>/batches/<NNN>.json`（BATCH_SIZE 件ずつ、判断に要る項目だけ）を 1 つずつ渡す
- GitHub から取った生の応答は、実行日に関係なく RAW_DIR（`<host>/<owner>/<repo>/<PR の番号>.json`）に
  貯め、コンテキストには入れない。集め直すとき（やり直し・除く条件を変えたとき・別の日の実行）は、RAW_DIR にある PR を
  GitHub から取り直さない。対象はマージ済みの PR なので、取ったあとに変わることはほとんど無い。取り直したい PR は
  そのファイルを消す

最後に 1 行の要約（JSON）を stdout に出す。
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import itertools
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import lessonlib as L

RAW_DIR = Path.home() / ".cache/agent-lessons/raw"
PR_LIMIT = 1000
MAX_CANDIDATES = 150
BATCH_SIZE = 50
DEFAULT_DAYS = 90
MAX_COMMENTS = 100
BODY_CHARS = 500
REPLY_CHARS = 200

REJECT = re.compile(
    r"対応しません|対応しない|見送|不要です|意図(どおり|通り)|仕様です|won't fix|wontfix|not (going to|gonna) fix|by design|\bintended\b",
    re.I,
)
RAW_VERSION = 2  # 1（レビュースレッドだけ）のファイルは会話タブ・レビュー本文が無いので取り直す

QUERY_THREADS = """
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      author { login }
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
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

# --paginate は最初に見つけた pageInfo しか辿らないので、ページを送る一覧ごとに問い合わせを分ける
QUERY_COMMENTS = """
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      comments(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { author { login __typename } body url }
      }
    }
  }
}
"""

QUERY_REVIEWS = """
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviews(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { author { login __typename } body url }
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
    for sub in ("inbox", "lessons", "archived"):
        for p in (L.LESSONS_DIR / sub).rglob("*.md"):
            text = p.read_text(encoding="utf-8")
            urls.update(re.findall(r"https?://\S+?#(?:discussion_r|issuecomment-|pullrequestreview-)\d+", text))
    return urls


def list_prs(host: str, repo: str, since: dt.date, until: dt.date, qualifier: str) -> list[dict]:
    """期間内にマージされた PR。上限に当たったら期間を半分に分けて取り直す。"""
    search = f"merged:{since}..{until} {qualifier}".strip()
    prs = gh("pr", "list", "-R", f"{host}/{repo}", "--state", "merged", "--search", search,
             "--limit", str(PR_LIMIT), "--json", "number,mergedAt")  # fmt: skip
    if len(prs) < PR_LIMIT or since >= until:
        if len(prs) >= PR_LIMIT:
            print(f"warning: {repo} {since} で {PR_LIMIT} 件を超えた。残りは取れていない", file=sys.stderr)
        return prs
    mid = since + (until - since) // 2
    return list_prs(host, repo, since, mid, qualifier) + list_prs(
        host, repo, mid + dt.timedelta(days=1), until, qualifier
    )


def fetch(host: str, owner: str, name: str, number: int) -> dict:
    """PR の作者と、レビュースレッド・会話タブのコメント・レビュー本文。"""
    path = RAW_DIR / host / owner / name / f"{number}.json"
    RAW_DIR.parent.mkdir(parents=True, exist_ok=True)
    for d in reversed([path.parent, *itertools.takewhile(lambda d: d != RAW_DIR.parent, path.parent.parents)]):
        d.mkdir(mode=0o700, exist_ok=True)
        d.chmod(0o700)
    if path.is_file():
        path.chmod(0o600)
    raw = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None
    if not isinstance(raw, dict) or raw.get("version") != RAW_VERSION:
        raw = {"version": RAW_VERSION}
        for key, query in (("threads", QUERY_THREADS), ("comments", QUERY_COMMENTS), ("reviews", QUERY_REVIEWS)):
            raw[key] = gh("api", "graphql", "--hostname", host, "--paginate", "--slurp",
                          "-F", f"owner={owner}", "-F", f"name={name}", "-F", f"number={number}", "-f", f"query={query}")  # fmt: skip
        # 途中で止まっても壊れたファイルを取得済みとして読まず、同時に動く別の実行とも一時ファイルを共有しない
        fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(raw, f, ensure_ascii=False)
        os.replace(tmp, path)

    def nodes(key: str, field: str) -> list[dict]:
        return [n for p in raw[key] for n in p["data"]["repository"]["pullRequest"][field]["nodes"]]

    return {
        "author": (raw["threads"][0]["data"]["repository"]["pullRequest"]["author"] or {}).get("login", ""),
        "threads": nodes("threads", "reviewThreads"),
        "comments": nodes("comments", "comments"),
        "reviews": nodes("reviews", "reviews"),
    }


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


def rejected(thread: dict, pr_author: str) -> bool:
    """PR の作者がスレッドで却下した指摘。採用されたかは判定しない（返信・resolve・Addressed in などの印が無いまま
    直された指摘も拾うため。誤った指摘や好みの違いは段階 1 のモデルが外す）。"""
    replies = thread["comments"]["nodes"][1:]
    return any(REJECT.search(r["body"]) for r in replies if (r["author"] or {}).get("login") == pr_author)


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
    next_since: dict[str, str] = {}
    left: dict[str, int] = {}

    for fname, conf in read_targets():
        since = dt.date.fromisoformat(state[fname]) if fname in state else today - dt.timedelta(days=DEFAULT_DAYS)
        targets_read[fname] = str(since)
        next_since[fname] = str(today)
        prs: dict[tuple[str, int], tuple[str, dict]] = {}
        for t in conf["repos"]:
            host = t["repo"].split("/")[0]
            if fname == "targets.yml":
                personal.append(t["repo"])
            if host not in logins:
                logins[host] = gh("api", "user", "--hostname", host)["login"]
            quals = [""] if t["team"] else ["author:@me", "reviewed-by:@me"]
            for q in quals:
                for p in list_prs(host, t["repo"].split("/", 1)[1], since, today, q):
                    prs[(t["repo"], p["number"])] = (p["mergedAt"][:10], t)

        count = 0
        ordered = sorted(prs.items(), key=lambda kv: (kv[1][0], kv[0]))
        for day, group in itertools.groupby(ordered, key=lambda kv: kv[1][0]):
            # 日の途中では止めない（次回はその日から集めるので、途中で止めると同じ日の PR を二重に集める）
            if count >= MAX_CANDIDATES:
                next_since[fname] = day
                left[fname] = sum(1 for _, (d, _) in ordered if d >= day)
                break
            for (repo, number), (_, t) in group:
                host, owner, name = repo.split("/")
                me = logins[host]
                pr = fetch(host, owner, name, number)
                pr_author = pr["author"]
                # 会話タブとレビュー本文は、作者の返信がどの指摘への却下か決められないので、却下では除かない
                items = []
                for th in pr["threads"]:
                    comments = th["comments"]
                    if comments["totalCount"] > MAX_COMMENTS or not comments["nodes"] or rejected(th, pr_author):
                        continue
                    last = comments["nodes"][-1] if len(comments["nodes"]) > 1 else None
                    items.append(("thread", comments["nodes"][0], th["path"], last))
                for kind in ("review", "comment"):
                    for c in pr[f"{kind}s"]:
                        if (c["author"] or {}).get("login") != pr_author and trim(c["body"], BODY_CHARS):
                            items.append((kind, c, "", None))
                for kind, first, path, last in items:
                    reviewer = (first["author"] or {}).get("login", "")
                    source = classify(me, pr_author, reviewer, t["team"])
                    if not source or first["url"] in seen:
                        continue
                    count += 1
                    candidates.append(
                        {
                            "id": f"c{len(candidates) + 1:04d}",
                            "kind": kind,
                            "source": source,
                            "scope_key": repo,
                            "targets_file": fname,
                            "evidence": first["url"],
                            "path": path,
                            "reviewer": "bot" if (first["author"] or {}).get("__typename") == "Bot" else "user",
                            "reviewer_hash": hashlib.sha1(f"{host}/{reviewer}".encode()).hexdigest()[:8],
                            "comment": trim(first["body"], BODY_CHARS),
                            "last_reply": trim(last["body"], REPLY_CHARS) if last else "",
                        }
                    )

    # モデルに渡すのは判断に要る項目だけ（根拠の URL・指摘者の hash などは write_observations.py が埋める）
    batches = [candidates[i : i + BATCH_SIZE] for i in range(0, len(candidates), BATCH_SIZE)]
    (args.work / "batches").mkdir(exist_ok=True)
    for old in (args.work / "batches").glob("*.json"):
        old.unlink()  # 集め直したときに、前回の余ったバッチを残さない
    for i, batch in enumerate(batches, 1):
        slim = [
            {k: c[k] for k in ("id", "kind", "source", "scope_key", "path", "reviewer", "comment", "last_reply")}
            for c in batch
        ]
        (args.work / "batches" / f"{i:03d}.json").write_text(
            json.dumps({"candidates": slim}, ensure_ascii=False, indent=1), encoding="utf-8"
        )

    result = {
        "until": str(today),
        "targets": targets_read,
        "next": next_since,
        "batches": len(batches),
        "personal_repos": personal,
        "candidates": candidates,
    }
    (args.work / "candidates.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    by_source: dict[str, int] = {}
    for c in candidates:
        by_source[c["source"]] = by_source.get(c["source"], 0) + 1
    summary = {"candidates": len(candidates), "batches": len(batches), "by_source": by_source, "left_prs": left}
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
