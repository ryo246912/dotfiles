"""観察（inbox）を教訓（lessons）へまとめる。どの教訓に入れるかはモデルが plan.json に書き、件数・根拠の追記・
昇格・失効の判定はこのスクリプトが決まった規則で行う。

    python3 apply_plan.py --list                         # 未処理の観察を短く出す（plan.json を書く材料）
    python3 apply_plan.py --work <作業ディレクトリ>       # plan.json を当て、pr-body.md を書く
    python3 apply_plan.py --work <作業ディレクトリ> --state-only   # 前回の実行日だけ進める（新しい指摘が無い週）

plan.json の書式（未処理の観察は、attach・create・skip のどれか 1 つに必ず入れる）:

    {
      "attach": [{"observation": "inbox/received/x.md", "lesson": "lessons/received/global/y.md"}],
      "create": [{"key": "doc-behavior-drift", "observations": ["inbox/received/z.md"], "scope_key": "github.com/o/r",
                  "title": "命令形の 1 文", "category": "...", "globs": [], "rule": "...", "why": "...", "check": "..."}],
      "skip":   [{"observation": "inbox/received/w.md", "reason": "一般化できない"}],
      "widen":  [{"lessons": ["lessons/received/github.com/o/a/x.md", "lessons/received/github.com/o/b/x.md"],
                  "scope_key": "github.com/o", "key": "...", "title": "...", "rule": "...", "why": "...", "check": "...",
                  "globs": []}],
      "escalate": {"lessons/received/global/y.md": "仕組みの案（どの lint のどのルール・どの hook・どのテストか）"},
      "review": ["ユーザーに判断してほしいこと"]
    }

教訓の `## Patterns`（よく出た形）は、観察の `## Patterns` をこのスクリプトが足していくので、plan.json には書かない。

widen は同じ教訓を上の scope（owner か global）にまとめる。global にまとめられるのは、根拠のリポジトリがすべて
targets.yml（個人）にあるときだけで、それ以外は行わずに「要確認」へ回す（global は個人のリポジトリにも注入されるため）。

昇格の規則:
  candidate → active  received・given は異なる PR とセッションの合計が 2 以上、team は異なる PR が 3 以上か指摘者が 2 人以上
  active → retired    last_seen から 90 日
  仕組み化の候補       active になった後に 2 回以上また指摘された（plan.json の escalate に案がある教訓も）。
                       escalation.md（チェックリスト）の「未対応」に足す。印が付いたら escalation.py が ruled にする
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

import escalation
import lessonlib as L

RETIRE_DAYS = 90
ESCALATE_AFTER = 2


def pending() -> list[tuple[Path, dict, str]]:
    out = []
    for p in sorted((L.LESSONS_DIR / "inbox").rglob("*.md")):
        meta, body = L.read(p)
        if meta.get("type") == "lesson_observation" and meta.get("status") == "pending":
            out.append((p, meta, body))
    return out


def obs_date(meta: dict) -> str:
    if meta.get("date"):
        return str(meta["date"])
    m = re.match(r"\d{4}-\d{2}-\d{2}", str(meta.get("title", "")))
    return m.group(0) if m else str(dt.date.today())


def evidence_line(meta: dict) -> str:
    ev = str(meta.get("evidence", ""))
    return f"- {ev}" if ev.startswith("session:") else f"- {ev} ({obs_date(meta)})"


def recount(meta: dict, body: str) -> None:
    ev = L.sections(body).get("Evidence", "")
    meta["prs"] = len(set(re.findall(r"https?://\S+?/pull/\d+", ev)))
    # セッション ID は残らないため、同じ日の訂正は 1 セッションとして数える（多めに数えて早く昇格させないため）
    meta["sessions"] = len(set(re.findall(r"^- session:\s*(\S+)", ev, re.M)))
    if meta.get("source") == "team":
        meta["reviewers"] = len(set(meta.get("reviewer_hashes") or []))


def add_observation(meta: dict, body: str, obs: dict, obs_body: str) -> str:
    meta["count"] = int(meta.get("count") or 0) + 1
    meta["last_seen"] = max(str(meta.get("last_seen") or ""), obs_date(obs))
    meta["first_seen"] = min(str(meta.get("first_seen") or "9999"), obs_date(obs))
    meta["repos"] = sorted(set(meta.get("repos") or []) | {obs["scope_key"]})
    if obs.get("reviewer_hash"):
        meta["reviewer_hashes"] = sorted(set(meta.get("reviewer_hashes") or []) | {obs["reviewer_hash"]})
    if meta.get("status") == "active":
        meta["since_active"] = int(meta.get("since_active") or 0) + 1
    meta["globs"] = L.normalize_globs([*(meta.get("globs") or []), *(obs.get("globs") or [])])
    have = L.bullets(L.sections(body).get("Patterns", ""))
    new = [b for b in L.bullets(L.sections(obs_body).get("Patterns", "")) if b not in have]
    if new:
        body = L.set_section(body, "Patterns", "\n".join((have + new)[-L.MAX_PATTERNS :]), before="Why")
    line = evidence_line(obs)
    if "## Evidence" not in body:
        body = body.rstrip() + "\n\n## Evidence\n"
    if line not in body:
        body = body.rstrip() + "\n" + line + "\n"
    return body


def new_lesson(spec: dict, source: str, today: str) -> tuple[dict, str]:
    meta = {
        "title": spec["title"],
        "type": "lesson",
        "status": "candidate",
        "source": source,
        "scope_key": spec["scope_key"],
        "category": spec["category"],
        "count": 0,
        "first_seen": today,
        "last_seen": today,
        "globs": L.normalize_globs(spec.get("globs")),
    }
    body = f"\n## Rule\n{spec['rule']}\n\n## Why\n{spec['why']}\n\n## Check\n{spec['check']}\n\n## Evidence\n"
    return meta, body


def lesson_path(source: str, scope_key: str, key: str) -> Path:
    return L.LESSONS_DIR / "lessons" / source / scope_key / f"{re.sub(r'[^\w-]+', '-', key).strip('-')}.md"


def check_plan(plan: dict, obs: dict) -> list[str]:
    """plan.json はモデルが書くので、書き込む前に割り当てと書き込み先をすべて検査する。

    書き込み先は LESSONS_DIR/lessons の中に限り、source と scope_key も決まった形だけを通す
    （週次は未信頼の PR コメントを読む無人実行なので、plan に紛れた `..` などで外を書き換えないため）。
    """
    assigned = [a["observation"] for a in plan.get("attach", [])]
    assigned += [o for c in plan.get("create", []) for o in c["observations"]]
    assigned += [s["observation"] for s in plan.get("skip", [])]
    errors = [f"未割り当て: {o}" for o in obs if o not in assigned]
    errors += [f"二重に割り当て: {o}" for o in set(assigned) if assigned.count(o) > 1]
    errors += [f"未処理の観察ではない: {o}" for o in assigned if o not in obs]
    if errors:
        return errors

    def lesson_ok(rel: str, where: str) -> dict | None:
        path = L.inside(rel, "lessons")
        if not path or not path.is_file():
            errors.append(f"{where}: lessons/ の中の既存の教訓ではない: {rel}")
            return None
        return L.read(path)[0]

    def spec_ok(spec: dict, where: str, required: tuple[str, ...]) -> None:
        if not L.SCOPE_KEY.fullmatch(str(spec.get("scope_key", ""))):
            errors.append(f"{where}: scope_key が不正: {spec.get('scope_key')}")
        if not re.fullmatch(r"[\w-]+", str(spec.get("key", ""))):
            errors.append(f"{where}: key は英数字と - だけにする: {spec.get('key')}")
        errors.extend(f"{where}: {k} が無い" for k in required if not spec.get(k))

    for i, a in enumerate(plan.get("attach", [])):
        meta = lesson_ok(a["lesson"], f"attach[{i}]")
        if meta and meta.get("status") == "retired":
            errors.append(f"attach[{i}]: retired の教訓には入れない（create にする）: {a['lesson']}")
        if meta and meta.get("source") != obs[a["observation"]][1].get("source"):
            errors.append(f"attach[{i}]: 観察と教訓の source が違う")
    for i, c in enumerate(plan.get("create", [])):
        spec_ok(c, f"create[{i}]", ("title", "category", "rule", "why", "check"))
        if len({obs[o][1].get("source") for o in c["observations"]}) != 1:
            errors.append(f"create[{i}]: source の違う観察を 1 つの教訓にまとめない")
    for i, w in enumerate(plan.get("widen", [])):
        spec_ok(w, f"widen[{i}]", ("title", "rule", "why", "check"))
        metas = [lesson_ok(p, f"widen[{i}]") for p in w.get("lessons", [])]
        if len({m.get("source") for m in metas if m}) > 1:
            errors.append(f"widen[{i}]: source の違う教訓をまとめない")
    for rel, proposal in (plan.get("escalate") or {}).items():
        meta = lesson_ok(rel, "escalate")
        if meta and meta.get("status") != "active":
            errors.append(f"escalate: active ではない教訓は仕組み化の候補にしない: {rel}")
        if not isinstance(proposal, str):
            errors.append(f"escalate: 案は文字列にする: {rel}")
    for o in obs.values():
        if o[1].get("source") not in L.SOURCES:
            errors.append(f"観察の source が不正: {o[0]}")

    # 教訓と pr-body.md に載る文章。日本語でない観察が inbox に残っていても、教訓へ移す前にここで止める
    texts = [(f"{w}[{i}].{k}", s.get(k, "")) for w in ("create", "widen") for i, s in enumerate(plan.get(w, []))
             for k in ("title", "rule", "why", "check")]  # fmt: skip
    texts += [(f"review[{i}]", r) for i, r in enumerate(plan.get("review", []))]
    texts += [(f"escalate: {rel}", p) for rel, p in (plan.get("escalate") or {}).items()]
    # Patterns は 1 行ずつ見る（日本語の行に混ざった英語だけの行も拾うため）
    texts += [(f"{rel} の {k}", ln) for rel, (_, _, b) in obs.items() for k, v in L.sections(b).items()
              if k in ("Rule", "Patterns", "Why", "Check") for ln in v.splitlines() if ln.strip()]  # fmt: skip
    errors += [f"{where} は日本語で書く（{e}）" for where, t in texts if (e := L.language_error(t))]
    return errors


def unfinished(work: Path) -> list[str]:
    """観察を書き終えていないバッチ（write_observations.py が .done を置いていないもの）。"""
    names = [p.stem for p in sorted((work / "batches").glob("*.json"))] + ["sessions"]
    return [n for n in names if not (work / "observations" / f"{n}.done").is_file()]


def advance_state(work: Path) -> None:
    """collect.py が読んだ targets ファイルの前回の実行日を、次回の開始日（上限で持ち越した分があればその日）に進める。"""
    collect = work / "candidates.json"
    if not collect.is_file():
        return
    data = json.loads(collect.read_text())
    state_path = L.LESSONS_DIR / "harvest-state.yml"
    state = {}
    if state_path.is_file():
        for line in state_path.read_text().splitlines():
            k, _, v = line.partition(":")
            if v.strip():
                state[k.strip()] = v.strip()
    state.update({f: data.get("next", {}).get(f, data["until"]) for f in data["targets"]})
    state_path.write_text("".join(f"{k}: {v}\n" for k, v in sorted(state.items())))


def personal_repos() -> set[str]:
    f = L.TARGETS_DIR / "targets.yml"
    if not f.is_file():
        return set()
    return set(re.findall(r"-\s*repo:\s*(\S+)", f.read_text(encoding="utf-8")))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--work", type=Path)
    ap.add_argument("--state-only", action="store_true")
    args = ap.parse_args()

    if args.work and not args.list:
        # 観察を書いていないバッチが残ったまま日付を進めると、その候補は二度と集まらない
        left = unfinished(args.work)
        if left:
            print(f"観察を書き終えていないバッチがある: {', '.join(left)}", file=sys.stderr)
            return 1

    if args.state_only:
        # 新しい指摘が無い週。教訓には触れず、次回に同じ PR を集め直さないよう前回の実行日だけ進める
        advance_state(args.work)
        return 0

    if args.list:
        L.check_schema(strict=False)
        items = [
            {
                "observation": str(p.relative_to(L.LESSONS_DIR)),
                "source": m.get("source"),
                "scope_key": m.get("scope_key"),
                "category": m.get("category"),
                "rule": L.sections(b).get("Rule", ""),
            }
            for p, m, b in pending()
        ]
        print(json.dumps(items, ensure_ascii=False, separators=(",", ":")))
        return 0

    L.check_schema(strict=True)
    work: Path = args.work
    plan = json.loads((work / "plan.json").read_text())
    today = str(dt.date.today())
    obs = {str(p.relative_to(L.LESSONS_DIR)): (p, m, b) for p, m, b in pending()}

    errors = check_plan(plan, obs)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    lessons: dict[Path, tuple[dict, str]] = {}

    def load(path: Path) -> tuple[dict, str]:
        if path not in lessons:
            lessons[path] = L.read(path)
        return lessons[path]

    review = list(plan.get("review", []))
    for a in plan.get("attach", []):
        path = L.inside(a["lesson"], "lessons")
        meta, body = load(path)
        _, o_meta, o_body = obs[a["observation"]]
        if meta.get("status") == "ruled":
            review.append(f"仕組み化した後にまた指摘された（仕組みが拾えない形かもしれない）: {meta['title']}")
        lessons[path] = (meta, add_observation(meta, body, o_meta, o_body))
    for c in plan.get("create", []):
        source = obs[c["observations"][0]][1]["source"]
        path = lesson_path(source, c["scope_key"], c["key"])
        meta, body = lessons.get(path) or (L.read(path) if path.is_file() else new_lesson(c, source, today))
        for o in c["observations"]:
            body = add_observation(meta, body, obs[o][1], obs[o][2])
        lessons[path] = (meta, body)

    widened = []
    mine = personal_repos()
    for w in plan.get("widen", []):
        srcs = [load(L.inside(p, "lessons")) for p in w["lessons"]]
        repos = set().union(*(set(m.get("repos") or []) for m, _ in srcs))
        if w["scope_key"] == "global" and not repos <= mine:
            review.append(f"global 化の候補（会社などのリポジトリが根拠に含まれるため保留）: {w['title']}")
            continue
        source = srcs[0][0]["source"]
        path = lesson_path(source, w["scope_key"], w["key"])
        # widen の書式に category は無いので、まとめる元の教訓から引き継ぐ
        meta, body = new_lesson({**w, "category": w.get("category") or srcs[0][0].get("category")}, source, today)
        meta.update(
            count=sum(int(m.get("count") or 0) for m, _ in srcs),
            first_seen=min(str(m.get("first_seen")) for m, _ in srcs),
            last_seen=max(str(m.get("last_seen")) for m, _ in srcs),
            repos=sorted(repos),
            reviewer_hashes=sorted(set().union(*(set(m.get("reviewer_hashes") or []) for m, _ in srcs))),
            status="active" if any(m.get("status") == "active" for m, _ in srcs) else "candidate",
        )
        patterns = list(dict.fromkeys(b for _, src in srcs for b in L.bullets(L.sections(src).get("Patterns", ""))))
        if patterns:
            body = L.set_section(body, "Patterns", "\n".join(patterns[-L.MAX_PATTERNS :]), before="Why")
        evidence = {ln for _, b in srcs for ln in L.sections(b).get("Evidence", "").splitlines() if ln.strip()}
        body = body.rstrip() + "\n" + "\n".join(sorted(evidence)) + "\n"
        lessons[path] = (meta, body)
        for p in w["lessons"]:
            m, b = load(L.inside(p, "lessons"))
            m["status"], m["merged_into"] = "retired", str(path.relative_to(L.LESSONS_DIR))
        widened.append(f"{w['title']}（{w['scope_key']}）")

    # 全教訓の件数を数え直し、昇格・失効を判定する
    for path in L.lesson_files():
        load(path)
    activated, retired, escalate = [], [], []
    proposals = plan.get("escalate") or {}
    cutoff = str(dt.date.today() - dt.timedelta(days=RETIRE_DAYS))
    for path, (meta, body) in lessons.items():
        if meta.get("type") != "lesson":
            continue
        recount(meta, body)
        st = meta.get("status")
        if st == "candidate":
            hits = meta["prs"] + meta["sessions"]
            if (meta["source"] != "team" and hits >= 2) or (
                meta["source"] == "team" and (meta["prs"] >= 3 or meta.get("reviewers", 0) >= 2)
            ):
                meta.update(status="active", activated=today, since_active=0)
                activated.append(meta["title"])
        elif st == "active":
            if str(meta.get("last_seen")) < cutoff:
                meta["status"] = "retired"
                retired.append(meta["title"])
            else:
                rel = str(path.relative_to(L.LESSONS_DIR))
                if rel in proposals or int(meta.get("since_active") or 0) >= ESCALATE_AFTER:
                    escalate.append((rel, meta["title"], proposals.get(rel, "")))

    for path, (meta, body) in lessons.items():
        L.write(path, meta, body)
    for p, meta, body in obs.values():
        meta["status"] = "processed"
        L.write(p, meta, body)

    # 既にチェックリストに載っている教訓は足さない（毎週同じ項目が増えないため）
    escalated = escalation.add(escalate)

    # 前回の実行日は、この週次 PR と一緒にだけ進める
    advance_state(work)

    def section(title: str, items: list[str]) -> str:
        return f"### {title}\n\n" + ("\n".join(f"- {i}" for i in items) if items else "なし") + "\n"

    created = [c["title"] for c in plan.get("create", [])]
    body = "\n".join(
        [
            f"観察 {len(obs)} 件（追加 {len(plan.get('attach', []))}・新規 {len(created)}・対象外 {len(plan.get('skip', []))}）\n",
            section("新しい候補", created),
            section("active になった教訓", activated),
            section("範囲を広げた教訓", widened),
            section("retired にした教訓", retired),
            section("仕組み化のチェックリスト（escalation.md）に足した教訓", escalated),
            section("要確認", review),
        ]
    )
    (work / "pr-body.md").write_text(body)
    print(json.dumps({"observations": len(obs), "activated": len(activated), "retired": len(retired),
                      "escalate": len(escalated), "review": len(review)}))  # fmt: skip
    return 0


if __name__ == "__main__":
    sys.exit(main())
