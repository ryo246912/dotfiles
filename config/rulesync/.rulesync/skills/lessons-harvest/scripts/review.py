"""agent-lessons の教訓を見直す（月次の lessons-review skill から呼ぶ）。似た教訓の統合・文面の書き直し・不要な教訓の
retired はモデルが plan に書き、根拠や件数の付け替え・長く candidate のままの教訓の失効はこのスクリプトが行う。

    python3 review.py --list --work <作業ディレクトリ>   # source ごとの教訓を <work>/<source>.json に書き、件数を出す
    python3 review.py --work <作業ディレクトリ>          # <work>/plan-<source>.json をすべて当て、pr-body.md を書く

plan-<source>.json の書式（どれも省略できる。1 つの教訓は merge・rewrite・retire のどれか 1 つにだけ書く。
ただし merge の into は rewrite にも書ける）:

    {
      "merge":   [{"into": "lessons/received/global/a.md", "lessons": ["lessons/received/github.com/o/r/b.md"],
                   "reason": "同じ仕組みの指摘"}],
      "rewrite": [{"lesson": "lessons/received/global/c.md",
                   "title": "...", "rule": "...", "why": "...", "check": "..."}],
      "retire":  [{"lesson": "lessons/team/github.com/o/r/d.md", "reason": "誤った指摘から作られた"}],
      "review":  ["ユーザーに判断してほしいこと"]
    }

merge は lessons の教訓を into へまとめる（`## Patterns`・`## Evidence`・件数を足し、元は retired にする）。
into は同じ source で、scope_key が同じかその上位（owner・global）の教訓に限る。global へまとめられるのは、根拠の
リポジトリがすべて個人のもの（targets.yml）のときだけ。範囲を広げるのは週次の widen が行うため、ここでは広げない。
ruled の教訓は仕組みで防いでいるので、merge に書かない。plan-<source>.json には、その source の教訓だけを書く。
rewrite は書いた項目（title・rule・why・check）だけを置き換える。
`## Patterns`・`## Evidence` は観察から来た根拠なので書き換えない。

candidate のまま `last_seen` から 180 日たった教訓は、plan に関係なく retired にする
（1 回しか出ていない指摘を残さないため）。retired にした教訓は、同じ相対パスのまま archived/ の下へ移す
（根拠の URL は collect.py が候補から除くのに使う）。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import escalation
import lessonlib as L
from apply_plan import archive_path, recount

CANDIDATE_RETIRE_DAYS = 180
TEXT_KEYS = ("title", "rule", "why", "check")


def stale_cutoff() -> str:
    return str(dt.date.today() - dt.timedelta(days=CANDIDATE_RETIRE_DAYS))


def is_stale(meta: dict) -> bool:
    return meta.get("status") == "candidate" and str(meta.get("last_seen")) <= stale_cutoff()


def material(meta: dict, body: str, rel: str) -> dict:
    sec = L.sections(body)
    return {
        "path": rel,
        "title": meta.get("title"),
        "status": meta.get("status"),
        "scope_key": meta.get("scope_key"),
        "repos": meta.get("repos") or [],
        "category": meta.get("category"),
        **{k: meta.get(k) for k in ("prs", "sessions", "reviewers", "last_seen") if k in meta},
        "rule": sec.get("Rule", ""),
        "why": sec.get("Why", ""),
        "check": sec.get("Check", ""),
        "patterns": [b[2:] for b in L.bullets(sec.get("Patterns", ""))],
        "evidence": [b[2:] for b in L.bullets(sec.get("Evidence", ""))],
    }


def list_material(work: Path) -> int:
    L.check_schema(strict=False)
    groups: dict[str, list[dict]] = {}
    stale = 0
    for path in L.lesson_files():
        meta, body = L.read(path)
        if meta.get("type") != "lesson":
            continue
        # どうせ retired にする教訓はモデルに読ませない
        if is_stale(meta):
            stale += 1
            continue
        rel = str(path.relative_to(L.LESSONS_DIR))
        groups.setdefault(str(meta.get("source")), []).append(material(meta, body, rel))
    # source はファイル名になるので、決まった形だけを通す（<work> の外へ書かないため）
    if bad := sorted(set(groups) - set(L.SOURCES)):
        print(f"source が不正な教訓がある: {', '.join(bad)}", file=sys.stderr)
        return 1
    work.mkdir(parents=True, exist_ok=True)
    for source, items in groups.items():
        (work / f"{source}.json").write_text(json.dumps(items, ensure_ascii=False, separators=(",", ":")))
    print(json.dumps({**{s: len(v) for s, v in groups.items()}, "stale": stale}))
    return 0


def load_plan(work: Path) -> dict[str, list]:
    """全 source の plan をまとめる。merge・rewrite・retire の項目には、教訓と照らすよう plan の source を付ける。"""
    plan: dict[str, list] = {"merge": [], "rewrite": [], "retire": [], "review": []}
    for f in sorted(work.glob("plan-*.json")):
        source = f.stem.removeprefix("plan-")
        for k, v in json.loads(f.read_text()).items():
            plan.setdefault(k, []).extend(v if k == "review" else ({**e, "source": source} for e in v))
    return plan


def check_plan(plan: dict[str, list]) -> list[str]:
    """plan はモデルが書くので、書き込む前にパス・source・scope と日本語かを検査する。"""
    errors: list[str] = []
    metas: dict[str, dict] = {}

    def lesson_ok(rel: str, where: str, source: str) -> dict | None:
        path = L.inside(rel, "lessons")
        if not path or not path.is_file():
            errors.append(f"{where}: lessons/ の中の既存の教訓ではない: {rel}")
            return None
        # 同じ教訓を別の書き方のパスで二重に読み書きしないよう、--list が出したままの形に限る
        if str(path.relative_to(L.LESSONS_DIR.resolve())) != rel:
            errors.append(f"{where}: --list が出したパスのまま書く: {rel}")
            return None
        metas[rel] = metas.get(rel) or L.read(path)[0]
        if metas[rel].get("source") != source:
            errors.append(f"{where}: plan-{source}.json に {metas[rel].get('source')} の教訓を書かない: {rel}")
        return metas[rel]

    used: list[str] = []
    for i, m in enumerate(plan["merge"]):
        into = lesson_ok(m.get("into", ""), f"merge[{i}].into", m["source"])
        used.append(m.get("into", ""))
        if not m.get("lessons"):
            errors.append(f"merge[{i}]: lessons が無い")
        for rel in m.get("lessons", []):
            src = lesson_ok(rel, f"merge[{i}]", m["source"])
            used.append(rel)
            scopes = [str(src.get("scope_key")), *(src.get("repos") or [])] if src else []
            if into and src and (e := L.scope_error(str(into.get("scope_key")), scopes)):
                errors.append(f"merge[{i}]: {e}（広げるのは週次の widen）: {rel}")
            if src and src.get("status") == "ruled":
                errors.append(f"merge[{i}]: ruled の教訓は仕組みで防いでいるのでまとめない: {rel}")
        if into and into.get("status") == "ruled":
            errors.append(f"merge[{i}]: ruled の教訓へはまとめない: {m.get('into')}")
    for i, r in enumerate(plan["retire"]):
        lesson_ok(r.get("lesson", ""), f"retire[{i}]", r["source"])
        used.append(r.get("lesson", ""))
    errors += [f"merge・retire に二重に書いた: {rel}" for rel in sorted(set(used)) if used.count(rel) > 1]

    gone = {rel for m in plan["merge"] for rel in m.get("lessons", [])} | {r.get("lesson") for r in plan["retire"]}
    rewritten = [r.get("lesson", "") for r in plan["rewrite"]]
    for i, r in enumerate(plan["rewrite"]):
        lesson_ok(r.get("lesson", ""), f"rewrite[{i}]", r["source"])
        if r.get("lesson") in gone:
            errors.append(f"rewrite[{i}]: 統合・retired にする教訓は書き直さない: {r.get('lesson')}")
        if not any(r.get(k) for k in TEXT_KEYS):
            errors.append(f"rewrite[{i}]: 書き直す項目（{'・'.join(TEXT_KEYS)}）が無い")
    errors += [f"rewrite に二重に書いた: {rel}" for rel in sorted(set(rewritten)) if rewritten.count(rel) > 1]

    texts = [(f"rewrite[{i}].{k}", r[k]) for i, r in enumerate(plan["rewrite"]) for k in TEXT_KEYS if r.get(k)]
    texts += [(f"merge[{i}].reason", m.get("reason", "")) for i, m in enumerate(plan["merge"])]
    texts += [(f"retire[{i}].reason", r.get("reason", "")) for i, r in enumerate(plan["retire"])]
    texts += [(f"review[{i}]", r) for i, r in enumerate(plan["review"])]
    errors += [f"{where} は日本語で書く（{e}）" for where, t in texts if (e := L.language_error(t))]
    return errors


def fold(meta: dict, body: str, src: dict, src_body: str) -> str:
    """src の観察を meta へ足す。件数は観察の数なので足し、PR・セッションは recount が `## Evidence` から数え直す。"""
    meta["count"] = int(meta.get("count") or 0) + int(src.get("count") or 0)
    meta["first_seen"] = min(str(meta.get("first_seen") or "9999"), str(src.get("first_seen") or "9999"))
    meta["last_seen"] = max(str(meta.get("last_seen") or ""), str(src.get("last_seen") or ""))
    meta["repos"] = sorted(set(meta.get("repos") or []) | set(src.get("repos") or []))
    hashes = set(meta.get("reviewer_hashes") or []) | set(src.get("reviewer_hashes") or [])
    if hashes:
        meta["reviewer_hashes"] = sorted(hashes)
    meta["globs"] = L.normalize_globs([*(meta.get("globs") or []), *(src.get("globs") or [])])
    if src.get("status") == "active":
        if meta.get("status") == "candidate":
            meta.update(status="active", activated=src.get("activated"), since_active=0)
        if meta.get("status") == "active":
            meta["since_active"] = int(meta.get("since_active") or 0) + int(src.get("since_active") or 0)
    sec, src_sec = L.sections(body), L.sections(src_body)
    patterns = list(dict.fromkeys(L.bullets(sec.get("Patterns", "")) + L.bullets(src_sec.get("Patterns", ""))))
    if patterns:
        body = L.set_section(body, "Patterns", "\n".join(patterns[-L.MAX_PATTERNS :]), before="Why")
    evidence = list(dict.fromkeys(L.bullets(sec.get("Evidence", "")) + L.bullets(src_sec.get("Evidence", ""))))
    return L.set_section(body, "Evidence", "\n".join(evidence))


def apply(work: Path) -> int:
    L.check_schema(strict=True)
    plan = load_plan(work)
    errors = check_plan(plan)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    today = str(dt.date.today())
    lessons: dict[str, tuple[Path, dict, str]] = {}

    def load(rel: str) -> tuple[Path, dict, str]:
        if rel not in lessons:
            path = L.inside(rel, "lessons")
            lessons[rel] = (path, *L.read(path))
        return lessons[rel]

    # escalation.md の「未対応」の向け先（統合先のパス。外すものは None）
    moves: dict[str, str | None] = {}
    merged, rewritten, retired, stale = [], [], [], []
    for m in plan["merge"]:
        path, meta, body = load(m["into"])
        titles = []
        for rel in m["lessons"]:
            _, src, src_body = load(rel)
            body = fold(meta, body, src, src_body)
            src.update(status="retired", merged_into=m["into"])
            titles.append(src["title"])
            moves[rel] = m["into"]
        lessons[m["into"]] = (path, meta, body)
        merged.append(f"{meta['title']} ← {' / '.join(titles)}: {m.get('reason', '')}")
    for r in plan["rewrite"]:
        path, meta, body = load(r["lesson"])
        old = meta["title"]
        if r.get("title"):
            meta["title"] = r["title"]
        for key, name, before in (
            ("rule", "Rule", "Patterns"),
            ("why", "Why", "Check"),
            ("check", "Check", "Evidence"),
        ):
            if r.get(key):
                body = L.set_section(body, name, r[key], before=before)
        lessons[r["lesson"]] = (path, meta, body)
        rewritten.append(old if old == meta["title"] else f"{old} → {meta['title']}")
    for r in plan["retire"]:
        _, meta, _ = load(r["lesson"])
        meta.update(status="retired", retire_reason=r.get("reason", ""))
        moves[r["lesson"]] = None
        retired.append(f"{meta['title']}: {r.get('reason', '')}")
    for path in L.lesson_files():
        rel = str(path.relative_to(L.LESSONS_DIR))
        _, meta, _ = load(rel)
        if meta.get("type") == "lesson" and is_stale(meta):
            meta.update(status="retired", retire_reason=f"candidate のまま {CANDIDATE_RETIRE_DAYS} 日たった")
            moves[rel] = None
            stale.append(meta["title"])

    changed = {m["into"] for m in plan["merge"]} | set(moves) | {r["lesson"] for r in plan["rewrite"]}
    for rel in changed:
        path, meta, body = lessons[rel]
        if meta.get("type") != "lesson":
            continue
        recount(meta, body)
        if meta.get("status") == "retired":
            L.write(archive_path(path, today), meta, body)
            path.unlink()
        else:
            L.write(path, meta, body)
    escalation.relink(moves, {rel: lessons[rel][1]["title"] for rel in changed})

    def section(title: str, items: list[str]) -> str:
        return f"### {title}\n\n" + ("\n".join(f"- {i}" for i in items) if items else "なし") + "\n"

    (work / "pr-body.md").write_text(
        "\n".join(
            [
                section("統合した教訓（統合先 ← 統合元）", merged),
                section("書き直した教訓", rewritten),
                section("retired にした教訓", retired),
                section(f"candidate のまま {CANDIDATE_RETIRE_DAYS} 日たって retired にした教訓", stale),
                section("要確認", plan["review"]),
            ]
        )
    )
    print(json.dumps({"merged": sum(len(m["lessons"]) for m in plan["merge"]), "rewritten": len(rewritten),
                      "retired": len(retired), "stale": len(stale), "review": len(plan["review"])}))  # fmt: skip
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--work", type=Path, required=True)
    args = ap.parse_args()
    return list_material(args.work) if args.list else apply(args.work)


if __name__ == "__main__":
    sys.exit(main())
