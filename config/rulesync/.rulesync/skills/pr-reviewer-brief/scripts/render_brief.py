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
      "mode": "pr",                                      # "ticket" なら TL;DR・スタック構成・前提知識・変更内容だけを出す
      "ticket": {...},                                   # 省けば <workdir>/ticket.json を使う（書式は下）
      "related_prs": [{"number": 123, "title": "...", "url": "...", "state": "open", "summary": "..."}],  # チケットモード用
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

ticket（ticket.json）の書式。前提知識の先頭に「チケットの内容」として出る:

    {"id": "ABC-123", "source": "Linear", "url": "https://...", "title": "...", "status": "In Progress",
     "fetched": true,                       # 取得できなかったら false（id と url だけ出す）
     "summary": "チケットの要約", "requirements": ["やること"], "acceptance": ["受け入れ条件"],
     "links": [{"title": "仕様書", "url": "https://..."}],
     # チケットの本文。要約せずに転記する。各セクションは「チケットの本文」に開閉できる形で出る（最初は閉じている）
     "sections": [{"title": "背景", "body": "本文", "images": [{"path": "ticket-images/1.png", "alt": "...", "caption": "..."}]}],
     "comments": [{"author": "alice", "date": "2026-10-01", "body": "本文"}]}

sections・comments の body では、空行で段落、`- ` で箇条書き、`1. ` で番号付き、`#` で始まる行で小見出し、
``` で囲んだ部分でコードになる。1 行に `![説明](ticket-images/1.png)` だけを書くと、その位置に画像を埋め込む。
画像は <workdir>/ticket-images/ の下のファイルだけを埋め込む（http(s) の URL ならリンクにする）。
"""

import argparse
import base64
import datetime as dt
import html
import json
import re
import sys
from pathlib import Path
from urllib.parse import quote

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
    url = f"https://github.com/{brief['repo']}/blob/{sha}/{quote(path, safe='/')}{anchor}"
    return f'<a href="{esc(url)}"><code>{esc(label)}</code></a>'


def safe_url(url: str | None) -> str | None:
    """href に入れてよい URL（http / https）だけを返す。それ以外（javascript: など）は None。"""
    return url if url and re.match(r"^https?://", url) else None


def link(url: str | None, label: str) -> str:
    """http(s) の URL ならリンクに、それ以外ならリンクにせず文字だけを出す。"""
    safe = safe_url(url)
    return f'<a href="{esc(safe)}">{label}</a>' if safe else label


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
    ticket = brief.get("ticket")
    if ticket:
        meta.append(f'<span class="badge">{link(ticket.get("url"), esc(ticket.get("id", "チケット")))}</span>')
    if brief.get("stack"):
        meta.append(f'<span class="badge">stack #{brief["stack"]["number"]} · {len(prs)} PR</span>')
    for pr in prs[:1] if not brief.get("stack") else []:
        meta.append(f'<span>{link(pr.get("url"), esc(brief.get("repo", "")) + "#" + str(pr["number"]))}</span>')
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
            f'<li class="{cls}"><div class="stack-head">{link(pr.get("url"), "#" + str(pr["number"]))}'
            f'<strong>{esc(pr["title"])}</strong><span class="tag">{esc(state)}</span>{size}</div>'
            f'<p class="stack-sum">{inline(pr.get("summary", ""))}</p></li>'
        )
    trunk = esc(brief["stack"].get("trunk", ""))
    return f'<ol class="stack-blocks">{"".join(blocks)}</ol><div class="stack-trunk">{trunk}</div>'


def ticket_block(ticket: dict, workdir: Path) -> str:
    title = esc(ticket.get("title") or "")
    label = f"{esc(ticket.get('id', ''))} {title}".strip()
    meta = " · ".join(esc(v) for v in (ticket.get("source"), ticket.get("status")) if v)
    parts = [f'<h3>チケットの内容</h3><p><strong>{link(ticket.get("url"), label)}</strong>'
             + (f' <span class="tag">{meta}</span>' if meta else "") + "</p>"]
    if not ticket.get("fetched", True):
        parts.append('<p class="evidence">チケットの内容は取得できなかった（ID と URL だけを載せている）</p>')
    if ticket.get("summary"):
        parts.append(f"<p>{inline(ticket['summary'])}</p>")
    for key, heading in (("requirements", "やること"), ("acceptance", "受け入れ条件")):
        if ticket.get(key):
            parts.append(f"<h4>{heading}</h4><ul>" + "".join(f"<li>{inline(i)}</li>" for i in ticket[key]) + "</ul>")
    if ticket.get("links"):
        items = "".join(f"<li>{link(l.get('url'), esc(l.get('title') or l.get('url', '')))}</li>" for l in ticket["links"])
        parts.append(f"<h4>関連リンク</h4><ul>{items}</ul>")
    parts.append(ticket_body(ticket, workdir))
    return "".join(parts)


def background_section(brief: dict, workdir: Path) -> str:
    bg = brief.get("background") or {}
    parts = [ticket_block(brief["ticket"], workdir)] if brief.get("ticket") else []
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
    stacked = {pr["number"] for pr in brief.get("prs", [])} if brief.get("stack") else set()
    related = [pr for pr in brief.get("related_prs") or [] if pr["number"] not in stacked]
    if related:
        items = "".join(
            f'<li>{link(pr.get("url"), "#" + str(pr["number"]))} {esc(pr.get("title", ""))}'
            f' <span class="tag">{esc(pr.get("state", ""))}</span>'
            + (f" — {inline(pr['summary'])}" if pr.get("summary") else "")
            + "</li>"
            for pr in related
        )
        parts.append(f"<h3>関連する PR</h3><ul>{items}</ul>")
    return "".join(parts)


IMAGE_TYPES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif",
               ".webp": "image/webp", ".svg": "image/svg+xml"}
MAX_TICKET_IMAGE = 5 * 1024 * 1024
MAX_TICKET_IMAGES = 20  # 1 つのチケットで埋め込む枚数の上限（HTML が大きくなりすぎないように）


def image_data_uri(path: Path) -> str:
    mime = IMAGE_TYPES.get(path.suffix.lower(), "image/png")
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def ticket_image(workdir: Path, src: str, alt: str, caption: str, budget: list[int]) -> str:
    """チケットの画像を埋め込む。<workdir>/ticket-images/ の外のファイル、大きすぎるもの、上限を超えた分は埋め込まない。

    budget は残りの枚数（[n]）。チケット全体で共有する。
    """
    src = src.strip().removeprefix("<").removesuffix(">")
    label = esc(caption or alt or src)
    if safe_url(src):
        return f'<p class="evidence">画像（取り込めなかった）: {link(src, label)}</p>'
    base = (workdir / "ticket-images").resolve()
    path = (workdir / src).resolve()
    if not path.is_relative_to(base) or path.suffix.lower() not in IMAGE_TYPES or not path.is_file():
        return f'<p class="evidence">画像が見つからない: <code>{esc(src)}</code></p>'
    if path.stat().st_size > MAX_TICKET_IMAGE:
        return f'<p class="evidence">画像が大きすぎるので載せていない: <code>{esc(src)}</code></p>'
    if budget[0] <= 0:
        return f'<p class="evidence">画像が多いので載せていない（{MAX_TICKET_IMAGES} 枚まで）: <code>{esc(src)}</code></p>'
    budget[0] -= 1
    figcaption = f"<figcaption>{inline(caption)}</figcaption>" if caption else ""
    return f'<figure><img src="{image_data_uri(path)}" alt="{esc(alt)}" loading="lazy" />{figcaption}</figure>'


def render_list(items: list[tuple[int, str, str, int]]) -> str:
    """(字下げ, ul / ol, 文字, 番号) の並びを、字下げで入れ子にしたリストにする。番号付きは最初の番号から始める。"""
    out, stack = [], []  # stack: (字下げ, タグ)
    for indent, tag, text, number in items:
        while stack and indent < stack[-1][0]:
            out.append(f"</li></{stack.pop()[1]}>")
        if stack and indent == stack[-1][0] and tag != stack[-1][1]:
            out.append(f"</li></{stack.pop()[1]}>")
        if not stack or indent > stack[-1][0]:
            start = f' start="{number}"' if tag == "ol" and number != 1 else ""
            out.append(f"<{tag}{start}><li>")
            stack.append((indent, tag))
        else:
            out.append("</li><li>")
        out.append(inline(text))
    while stack:
        out.append(f"</li></{stack.pop()[1]}>")
    return "".join(out)


def rich_text(text: str, workdir: Path, budget: list[int]) -> str:
    """チケットの本文を HTML にする（段落・箇条書き・小見出し・コード・画像）。"""
    out, para, items, code = [], [], [], None

    def flush() -> None:
        nonlocal para, items
        if para:
            out.append("<p>" + "<br />".join(inline(line) for line in para) + "</p>")
        if items:
            out.append(render_list(items))
        para, items = [], []

    for line in text.splitlines():
        if code is not None:
            if line.strip().startswith("```"):
                out.append(f"<pre><code>{esc(chr(10).join(code))}</code></pre>")
                code = None
            else:
                code.append(line)
            continue
        stripped = line.strip()
        bullet = re.match(r"^[-*] (.*)", stripped)
        number = re.match(r"^(\d+)[.)] (.*)", stripped)
        image = re.fullmatch(r"!\[([^\]]*)\]\((<[^>\s]+>|[^)\s]+)\)", stripped)
        if stripped.startswith("```"):
            flush()
            code = []
        elif not stripped:
            if para:  # 箇条書きは空行をはさんでも続く（番号を振り直さない）
                flush()
        elif image:
            flush()
            out.append(ticket_image(workdir, image.group(2), image.group(1), "", budget))
        elif stripped.startswith("#"):
            flush()
            out.append(f"<h5>{inline(stripped.lstrip('#').strip())}</h5>")
        elif bullet or number:
            if para:
                flush()
            indent = len(line.expandtabs(4)) - len(line.expandtabs(4).lstrip())
            if bullet:
                items.append((indent, "ul", bullet.group(1), 1))
            else:
                items.append((indent, "ol", number.group(2), int(number.group(1))))
        else:
            if items:
                flush()
            para.append(stripped)
    if code is not None:
        out.append(f"<pre><code>{esc(chr(10).join(code))}</code></pre>")
    flush()
    return "".join(out)


def ticket_body(ticket: dict, workdir: Path) -> str:
    """チケットの本文とコメントを、セクションごとに開閉できる形で出す。"""
    blocks, budget = [], [MAX_TICKET_IMAGES]
    for sec in ticket.get("sections") or []:
        body = rich_text(sec.get("body", ""), workdir, budget)
        images = "".join(
            ticket_image(workdir, img.get("path", ""), img.get("alt", ""), img.get("caption", ""), budget)
            for img in sec.get("images") or []
        )
        count = f' <span class="tag">画像 {len(sec["images"])}</span>' if sec.get("images") else ""
        blocks.append(
            f'<details class="ticket-sec"><summary>{inline(sec.get("title") or "本文")}{count}</summary>'
            f'<div class="ticket-body">{body}{images}</div></details>'
        )
    comments = ticket.get("comments") or []
    if comments:
        items = "".join(
            f'<div class="ticket-comment"><p class="evidence">{esc(c.get("author", ""))}'
            f'{" · " + esc(c["date"]) if c.get("date") else ""}</p>{rich_text(c.get("body", ""), workdir, budget)}</div>'
            for c in comments
        )
        blocks.append(
            f'<details class="ticket-sec"><summary>コメント <span class="tag">{len(comments)} 件</span></summary>'
            f'<div class="ticket-body">{items}</div></details>'
        )
    return "<h4>チケットの本文</h4>" + "".join(blocks) if blocks else ""


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
            rows.append(f'<dt>URL</dt><dd>{link(step["url"], "<code>" + esc(step["url"]) + "</code>")}</dd>')
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
    shas_path = workdir / "shas.json"
    if shas_path.exists():  # 段階 1 が固定した SHA を、brief に無ければ使う
        for key, value in json.loads(shas_path.read_text()).items():
            brief.setdefault(key, value)
    ticket_path = workdir / "ticket.json"
    if ticket_path.exists() and "ticket" not in brief:
        brief["ticket"] = json.loads(ticket_path.read_text())
    ticket_mode = brief.get("mode") == "ticket"
    errors = [f"brief.json に {key} が無い" for key in ("title", "tldr") if not brief.get(key)]

    hunks_path, groups_path = workdir / "hunks.json", workdir / "groups.json"
    groups_html = ""
    has_hunks, has_groups = hunks_path.exists(), groups_path.exists()
    if has_hunks != has_groups:
        errors.append("hunks.json と groups.json は両方そろえる（片方だけでは変更グループを作れない）")
    elif has_hunks and not ticket_mode:
        hunks = {h["id"]: h for h in json.loads(hunks_path.read_text())["hunks"]}
        groups = json.loads(groups_path.read_text())["groups"]
        errors += validate_groups(hunks, groups, "full")
        if not errors:
            blob = f"https://github.com/{brief['repo']}/blob/{brief['head_sha']}" if brief.get("repo") and brief.get("head_sha") else None
            groups_html = render_groups(hunks, groups, blob)

    pictures = []
    for i, spec in enumerate([] if ticket_mode else brief.get("pictures", []), start=1):
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
        ("background", "前提知識", background_section(brief, workdir)),
        ("changes", "変更内容", changes_section(brief)),
    ):
        if body:
            sections.append(section(sid, title, body))
    # チケットモードは TL;DR・スタック構成・前提知識・変更内容だけ
    interfaces = None if ticket_mode else brief.get("interfaces")
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
    body = "" if ticket_mode else manual_test_section(brief, workdir)
    if body:
        sections.append(section("manual-test", "動作確認手順", body))
    if brief.get("focus") and not ticket_mode:
        items = "".join(
            f"<li>{blob_link(brief, f['path'], f.get('lines'), 'head')} — {inline(f['why'])}</li>" for f in brief["focus"]
        )
        sections.append(section("focus", "重点的に見る箇所", f"<ul>{items}</ul>"))
    if brief.get("unknowns") and not ticket_mode:
        items = "".join(f"<li>{inline(u)}</li>" for u in brief["unknowns"])
        sections.append(section("unknowns", "未確認事項", f"<ul>{items}</ul>"))

    nav = "<nav>" + "".join(f'<a href="#{sid}">{esc(title)}</a>' for sid, title, _ in sections) + "</nav>"
    content = header(brief, bool(groups_html)) + "".join(body for _, _, body in sections)
    values = {
        "title": esc(brief["title"]),
        "head_sha": esc(brief.get("head_sha", "")),
        "generated": dt.datetime.now().isoformat(timespec="seconds"),
        "nav": nav,
        "content": content,
    }
    # 1 回の置換で埋める（差し込んだ値の中に {{...}} があっても、それは置き換えない）
    page = re.sub(r"\{\{(title|head_sha|generated|nav|content)\}\}", lambda m: values[m.group(1)], PAGE.read_text())
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
