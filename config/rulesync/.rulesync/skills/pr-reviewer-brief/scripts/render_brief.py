"""作業ディレクトリの brief.json・hunks.json・groups.json・スクリーンショットから、資料の HTML を 1 ファイルで作る。

    python3 render_brief.py --workdir ./plan/.pr-reviewer-brief/pr-123 --out ./plan/pr-123.html

モデルは中身（brief.json）だけを書き、HTML・CSS・図の座標・差分の表はすべてここで作る。
文章の中では `コード`・**強調**・[文字](URL) が使える。書くことが無い項目は省くか空にする（その章は出ない）。
スクリーンショットは <workdir>/screenshots/manifest.json があれば、手順の id で対応させて埋め込む。

brief.json の書式:

    {
      "title": "資料のタイトル（stack なら stack 全体を表す名前）",
      "repo": "owner/name",
      "base_sha": "変更前の SHA（根拠のリンク用）", "head_sha": "head の SHA（stack なら一番上の PR）",
      "prs": [{"number": 123, "title": "...", "url": "...", "state": "open", "author": "alice",
               "base": "main", "head": "feature", "files": 3, "additions": 10, "deletions": 2,
               "summary": "stack のとき: この PR が受け持つ範囲を 1〜2 行", "current": true}],
      "stack": {"number": 7, "trunk": "main"},           # stack でなければ null か省く
      "tldr": ["1 行目", "2 行目", "3 行目"],
      "pictures": [<render_pictures.py の指定>],
      "background": {
        "current": [{"text": "今の機能の説明", "evidence": [{"path": "app/x.ts", "lines": "10-20"}]}],
        "glossary": [{"term": "用語", "meaning": "意味", "code": "コード上の名前"}],
        "data_model": {"note": "補足", "before": "erDiagram ...", "after": "erDiagram ..."}
      },
      "changes": {
        "before_after": [{"aspect": "観点", "before": "変更前", "after": "変更後"}],
        "sequences": [{"title": "難しいやりとりの名前", "mermaid": "sequenceDiagram ..."}]
      },
      "interfaces": [{"kind": "DB / API / 設定 / flag", "target": "対象", "change": "変更", "compat": "互換性・移行"}],
      "manual_test": {
        "environment": "どこで確かめるか（起動コマンドなど）",
        "preconditions": ["feature flag・権限・データなど"],
        "steps": [{"id": "step-1", "title": "何を確かめるか", "url": "http://localhost:3000/x",
                   "actions": "操作", "expected": "期待結果", "caution": "破壊的な操作の注意（任意）"}]
      },
      "focus": [{"path": "app/x.ts", "lines": "10", "why": "なぜ見るべきか"}],
      "unknowns": ["調べきれなかったこと・置いた仮定"]
    }

evidence と focus の path は、base_sha（evidence）・head_sha（focus）の GitHub のリンクになる。evidence に
"side": "head" を付けると head 側にする。
"""

import argparse
import base64
import datetime as dt
import html
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from render_groups import render as render_groups  # noqa: E402
from render_groups import validate as validate_groups  # noqa: E402
from render_pictures import render_picture  # noqa: E402

PAGE = Path(__file__).resolve().parent.parent / "assets" / "page.html"
esc = html.escape


def inline(text: str) -> str:
    """`code`・**強調**・[文字](URL) だけを HTML にする。"""
    out = esc(text)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', out)
    return out


def blob_link(brief: dict, path: str, lines: str | None, side: str) -> str:
    sha = brief.get("head_sha" if side == "head" else "base_sha")
    label = f"{path}:{lines}" if lines else path
    if not (brief.get("repo") and sha):
        return f"<code>{esc(label)}</code>"
    anchor = ""
    if lines:
        start, _, end = str(lines).partition("-")
        anchor = f"#L{start}" + (f"-L{end}" if end else "")
    url = f"https://github.com/{brief['repo']}/blob/{sha}/{path}{anchor}"
    return f'<a href="{esc(url)}"><code>{esc(label)}</code></a>'


def table(headers: list[str], rows: list[list[str]]) -> str:
    head = "".join(f"<th>{esc(h)}</th>" for h in headers)
    body = "".join("<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>" for row in rows)
    return f'<div class="table-wrap"><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def section(sid: str, title: str, body: str) -> tuple[str, str, str]:
    return sid, title, f'<section id="{sid}"><h2>{esc(title)}</h2>{body}</section>'


def mermaid(code: str) -> str:
    return f'<pre class="mermaid">{esc(code)}</pre>'


def header(brief: dict, has_groups: bool) -> str:
    prs = brief.get("prs", [])
    meta = []
    if brief.get("stack"):
        meta.append(f'<span class="badge">stack #{brief["stack"]["number"]} · {len(prs)} PR</span>')
    for pr in prs[:1] if not brief.get("stack") else []:
        meta.append(f'<span><a href="{esc(pr["url"])}">{esc(brief.get("repo", ""))}#{pr["number"]}</a></span>')
        meta.append(f"<span>作成者 {esc(pr.get('author', ''))}</span>")
        meta.append(f'<span><code>{esc(pr.get("base", ""))}</code> ← <code>{esc(pr.get("head", ""))}</code></span>')
    if brief.get("head_sha"):
        meta.append(f'<span>head <code>{esc(brief["head_sha"][:7])}</code></span>')
    meta.append(f"<span>生成 {dt.datetime.now().strftime('%Y-%m-%d %H:%M')}</span>")
    progress = (
        '<div class="meta"><span class="tag" id="diff-stats"></span><span class="progress">確認 '
        '<span id="progress-text">0/0</span><span class="progress-bar"><span id="progress-fill"></span></span></span></div>'
        if has_groups
        else ""
    )
    return f'<header><h1>{esc(brief["title"])}</h1><div class="meta">{"".join(meta)}</div>{progress}</header>'


def stack_section(brief: dict) -> str:
    blocks = []
    for pr in brief.get("prs", []):
        state = pr.get("state", "open").lower()
        cls = " ".join(c for c in ("current" if pr.get("current") else "", "merged" if state == "merged" else "") if c)
        size = (
            f'<span class="tag">{pr.get("files", 0)} files</span><span class="added">+{pr.get("additions", 0)}</span>'
            f'<span class="removed">−{pr.get("deletions", 0)}</span>'
        )
        blocks.append(
            f'<li class="{cls}"><div class="stack-head"><a href="{esc(pr["url"])}">#{pr["number"]}</a>'
            f'<strong>{esc(pr["title"])}</strong><span class="tag">{esc(state)}</span>{size}</div>'
            f'<p class="stack-sum">{inline(pr.get("summary", ""))}</p></li>'
        )
    trunk = esc(brief["stack"].get("trunk", ""))
    return f'<ol class="stack-blocks">{"".join(blocks)}</ol><div class="stack-trunk">{trunk}</div>'


def background_section(brief: dict) -> str:
    bg = brief.get("background") or {}
    parts = []
    if bg.get("current"):
        parts.append("<h3>今の機能</h3>")
        for item in bg["current"]:
            parts.append(f"<p>{inline(item['text'])}</p>")
            links = [blob_link(brief, e["path"], e.get("lines"), e.get("side", "base")) for e in item.get("evidence", [])]
            if links:
                parts.append(f'<p class="evidence">根拠: {" / ".join(links)}</p>')
    if bg.get("glossary"):
        rows = [[inline(g["term"]), inline(g["meaning"]), f"<code>{esc(g.get('code', ''))}</code>"] for g in bg["glossary"]]
        parts.append("<h3>用語集</h3>" + table(["用語", "意味", "コード上の名前"], rows))
    model = bg.get("data_model")
    if model:
        parts.append("<h3>データモデル</h3>")
        if model.get("note"):
            parts.append(f"<p>{inline(model['note'])}</p>")
        if model.get("before") and model.get("after"):
            parts.append(f"<h4>変更前</h4>{mermaid(model['before'])}<h4>変更後</h4>{mermaid(model['after'])}")
        elif model.get("before") or model.get("after"):
            parts.append(mermaid(model.get("after") or model["before"]))
    return "".join(parts)


def changes_section(brief: dict) -> str:
    changes = brief.get("changes") or {}
    parts = []
    if changes.get("before_after"):
        rows = [[inline(r["aspect"]), inline(r["before"]), inline(r["after"])] for r in changes["before_after"]]
        parts.append("<h3>変更前と変更後</h3>" + table(["観点", "変更前", "変更後"], rows))
    for seq in changes.get("sequences", []):
        parts.append(f"<h3>{esc(seq['title'])}</h3>{mermaid(seq['mermaid'])}")
    return "".join(parts)


def image_data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def manual_test_section(brief: dict, workdir: Path) -> str:
    test = brief.get("manual_test") or {}
    manifest_path = workdir / "screenshots" / "manifest.json"
    shots = {s["id"]: s for s in json.loads(manifest_path.read_text())} if manifest_path.exists() else {}
    parts = []
    if test.get("environment"):
        parts.append(f"<h3>環境</h3><p>{inline(test['environment'])}</p>")
    if test.get("preconditions"):
        parts.append("<h3>前提</h3><ul>" + "".join(f"<li>{inline(p)}</li>" for p in test["preconditions"]) + "</ul>")
    steps = []
    for step in test.get("steps", []):
        rows = []
        if step.get("url"):
            url = esc(step["url"])
            rows.append(f'<dt>URL</dt><dd><a href="{url}"><code>{url}</code></a></dd>')
        rows.append(f"<dt>操作</dt><dd>{inline(step.get('actions', ''))}</dd>")
        rows.append(f"<dt>期待結果</dt><dd>{inline(step.get('expected', ''))}</dd>")
        caution = f'<p class="callout">{inline(step["caution"])}</p>' if step.get("caution") else ""
        figure = ""
        shot = shots.get(step.get("id"))
        if shot and shot.get("ok") and (workdir / "screenshots" / shot["path"]).exists():
            uri = image_data_uri(workdir / "screenshots" / shot["path"])
            figure = (
                f'<figure><img src="{uri}" alt="{esc(step.get("title", ""))}" loading="lazy" />'
                f"<figcaption>{esc(step.get('title', ''))}</figcaption></figure>"
            )
        elif shot:
            figure = f'<p class="evidence">スクリーンショットを撮れなかった: {esc(shot.get("error", ""))}</p>'
        steps.append(
            f'<li id="{esc(step.get("id", ""))}"><h3>{inline(step.get("title", ""))}</h3>'
            f'<dl class="step">{"".join(rows)}</dl>{caution}{figure}</li>'
        )
    if steps:
        parts.append(f'<ol class="steps">{"".join(steps)}</ol>')
    return "".join(parts)


def build(workdir: Path) -> tuple[str, list[str]]:
    brief = json.loads((workdir / "brief.json").read_text())
    errors = [f"brief.json に {key} が無い" for key in ("title", "tldr") if not brief.get(key)]

    hunks_path, groups_path = workdir / "hunks.json", workdir / "groups.json"
    groups_html = ""
    if hunks_path.exists() and groups_path.exists():
        hunks = {h["id"]: h for h in json.loads(hunks_path.read_text())["hunks"]}
        groups = json.loads(groups_path.read_text())["groups"]
        errors += validate_groups(hunks, groups, "full")
        if not errors:
            blob = f"https://github.com/{brief['repo']}/blob/{brief['head_sha']}" if brief.get("repo") and brief.get("head_sha") else None
            groups_html = render_groups(hunks, groups, blob)

    pictures = []
    for i, spec in enumerate(brief.get("pictures", []), start=1):
        try:
            pictures.append(render_picture(spec, i))
        except (KeyError, ValueError) as error:
            errors.append(f"pictures[{i - 1}]: {error!r}")
    if errors:
        return "", errors

    sections = []
    tldr = "".join(f"<p>{inline(line)}</p>" for line in brief["tldr"])
    sections.append(section("tldr", "TL;DR", f'<div class="tldr">{tldr}</div>'))
    if pictures:
        legend = (
            '<div class="legend"><span>変わらない</span><span class="lg-changed">変わる</span>'
            '<span class="lg-added">増える</span><span class="lg-removed">なくなる</span></div>'
        )
        sections.append(section("pictures", "絵で見る", legend + f'<div class="pictures">{"".join(pictures)}</div>'))
    if brief.get("stack"):
        sections.append(section("stack", "スタック構成", stack_section(brief)))
    for sid, title, body in (
        ("background", "前提知識", background_section(brief)),
        ("changes", "変更内容", changes_section(brief)),
    ):
        if body:
            sections.append(section(sid, title, body))
    interfaces = brief.get("interfaces")
    if interfaces is not None:
        body = (
            table(
                ["種類", "対象", "変更", "互換性・移行"],
                [[inline(i["kind"]), inline(i["target"]), inline(i["change"]), inline(i.get("compat", ""))] for i in interfaces],
            )
            if interfaces
            else "<p>なし</p>"
        )
        sections.append(section("interfaces", "スキーマ・API・設定の差分", body))
    if groups_html:
        sections.append(section("groups", "変更グループ", groups_html))
    body = manual_test_section(brief, workdir)
    if body:
        sections.append(section("manual-test", "動作確認手順", body))
    if brief.get("focus"):
        items = "".join(
            f"<li>{blob_link(brief, f['path'], f.get('lines'), 'head')} — {inline(f['why'])}</li>" for f in brief["focus"]
        )
        sections.append(section("focus", "重点的に見る箇所", f"<ul>{items}</ul>"))
    if brief.get("unknowns"):
        items = "".join(f"<li>{inline(u)}</li>" for u in brief["unknowns"])
        sections.append(section("unknowns", "未確認事項", f"<ul>{items}</ul>"))

    nav = "<nav>" + "".join(f'<a href="#{sid}">{esc(title)}</a>' for sid, title, _ in sections) + "</nav>"
    content = header(brief, bool(groups_html)) + "".join(body for _, _, body in sections)
    page = PAGE.read_text()
    for key, value in (
        ("{{title}}", esc(brief["title"])),
        ("{{head_sha}}", esc(brief.get("head_sha", ""))),
        ("{{generated}}", dt.datetime.now().isoformat(timespec="seconds")),
        ("{{nav}}", nav),
        ("{{content}}", content),
    ):
        page = page.replace(key, value, 1)
    return page, []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--workdir", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    page, errors = build(args.workdir)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(page)
    print(args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
