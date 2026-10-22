"""「絵で見る」の絵を、JSON の指定から inline SVG にする（render_brief.py から使う）。

座標はここで計算するので、指定には「何を描くか」だけを書く。絵の種類は 4 つ。

before_after: 変更前と変更後を左右に並べる。各側は左から右へ流れる箱の列

    {"type": "before_after", "title": "この PR は何をする？", "lead": "1 文",
     "before": {"nodes": [{"label": "ユーザー", "kind": "actor", "icon": "👤"},
                          {"label": "設定画面"}, {"label": "保存 API"}],
                "note": "困っていること"},
     "after":  {"nodes": [{"label": "ユーザー", "kind": "actor", "icon": "👤"},
                          {"label": "設定画面", "status": "changed"},
                          {"label": "下書き保存", "sub": "DraftService", "status": "added"}],
                "note": "どう良くなるか"}}

touch_map: 「どこを触る？」の地図。画面（ページ）を列、層（画面の部品・共通部品・API・データなど）を行にして、
触る部品を色と変更グループの番号で示す。部品は使われている画面の列に置き、複数の画面で使う部品は
その列をまたいで横に伸ばす（pages を省くと全画面共通）。pages の id は brief.json の background.pages の id。
touch_map の pages を省くと、render_brief.py が background.pages を使う

    {"type": "touch_map", "title": "どこを触る？", "lead": "1 文",
     "rows": [{"name": "画面の部品", "items": [{"label": "土地カード", "pages": ["list"], "status": "changed", "groups": [10]},
                                              {"label": "対象土地列", "pages": ["detail"], "status": "changed", "groups": [10]}]},
              {"name": "API", "items": [{"label": "CRUD", "sub": "crud/approach.py", "status": "changed", "groups": [2, 4]}]},
              {"name": "データ", "items": [{"label": "アプローチ記録", "sub": "集計だけ"}]}]}

layers（古い形。新しく描くときは touch_map を使う）: 層ごとに箱を横に並べ、触る箱に色と番号を付ける

    {"type": "layers", "title": "どこを触る？", "lead": "1 文",
     "layers": [{"name": "画面", "nodes": [{"label": "設定画面", "status": "changed", "badge": 2},
                                           {"label": "一覧画面"}]},
                {"name": "共通処理", "nodes": [{"label": "URL 生成", "status": "changed", "badge": 1}]}]}

flow: 箱と矢印の図（データの流れ・状態遷移など）。nodes は流れの順に並べる。左の列から右へ配置する

    {"type": "flow", "title": "データはどう流れる？", "lead": "1 文",
     "nodes": [{"id": "form", "label": "入力フォーム"}, {"id": "api", "label": "API", "status": "changed"},
               {"id": "db", "label": "drafts テーブル", "status": "added"}],
     "edges": [{"from": "form", "to": "api", "label": "送信"},
               {"from": "api", "to": "db", "label": "保存", "status": "added"}]}

共通:

- status は same（既定）/ changed（変わる）/ added（増える）/ removed（なくなる）。edge にも付けられる
- node の label は改行（\\n）で折り返せる。sub は小さな補足（クラス名など）。kind: "actor" は枠なしで icon と label を出す
- caption（任意）は絵の下に出す。推測で描いた部分があれば、ここに「推測」と書く
- wide（任意）で横幅いっぱいに出す。before_after と、4 列以上の flow は既定で wide
"""

import html

esc = html.escape

FONT = 14
SMALL = 12
LINE = 19
PAD_X = 14
PAD_Y = 12
GAP_X = 44
GAP_Y = 28
MIN_BOX_W = 108
SIDE_BY_SIDE_MAX = 960
STATUSES = ("same", "changed", "added", "removed")


def text_width(text: str, size: int = FONT) -> float:
    return sum(size if ord(ch) > 0x2000 else size * 0.6 for ch in text)


def node_size(node: dict) -> tuple[float, float]:
    lines = node["label"].split("\n")
    width = max(text_width(line) for line in lines)
    height = LINE * len(lines)
    if node.get("sub"):
        width = max(width, text_width(node["sub"], SMALL))
        height += LINE - 3
    if node.get("kind") == "actor":
        return max(width, 40) + 8, height + 34
    return max(MIN_BOX_W, width + PAD_X * 2), height + PAD_Y * 2


def status_of(item: dict) -> str:
    status = item.get("status", "same")
    if status not in STATUSES:
        raise ValueError(f"status は {' / '.join(STATUSES)} のどれか: {status}")
    return status


class Canvas:
    def __init__(self, marker_id: str) -> None:
        self.marker_id = marker_id
        self.parts: list[str] = []

    def text(self, x: float, y: float, value: str, cls: str = "", anchor: str = "start") -> None:
        cls_attr = f' class="{cls}"' if cls else ""
        self.parts.append(f'<text{cls_attr} x="{x:.0f}" y="{y:.0f}" text-anchor="{anchor}">{esc(value)}</text>')

    def node(self, node: dict, x: float, y: float, w: float, h: float) -> None:
        status = status_of(node)
        lines = node["label"].split("\n")
        if node.get("kind") == "actor":
            self.text(x + w / 2, y + 26, node.get("icon", "👤"), "icon", "middle")
            for i, line in enumerate(lines):
                self.text(x + w / 2, y + 44 + i * LINE, line, "small", "middle")
            return
        cls = "box" if status == "same" else f"box {status}"
        self.parts.append(f'<rect class="{cls}" x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" rx="10" />')
        content_h = LINE * len(lines) + (LINE - 3 if node.get("sub") else 0)
        top = y + (h - content_h) / 2 + FONT
        for i, line in enumerate(lines):
            self.text(x + w / 2, top + i * LINE, line, "", "middle")
        if node.get("sub"):
            self.text(x + w / 2, top + len(lines) * LINE - 2, node["sub"], "small", "middle")
        if node.get("badge") is not None:
            self.parts.append(f'<circle class="badge" cx="{x + w - 4:.0f}" cy="{y + 4:.0f}" r="12" />')
            self.text(x + w - 4, y + 8, str(node["badge"]), "badge-text", "middle")

    def edge(self, path: str, status: str = "same", label: str | None = None, at: tuple[float, float] | None = None) -> None:
        if status not in STATUSES:
            raise ValueError(f"edge の status は {' / '.join(STATUSES)} のどれか: {status}")
        cls = "edge" if status == "same" else f"edge {status}"
        self.parts.append(f'<path class="{cls}" d="{path}" marker-end="url(#{self.marker_id}-{status})" />')
        if label and at:
            w = text_width(label, SMALL) + 10
            self.parts.append(
                f'<rect class="label-bg" x="{at[0] - w / 2:.0f}" y="{at[1] - 11:.0f}" width="{w:.0f}" height="16" rx="4" />'
            )
            self.text(at[0], at[1] + 1, label, "small", "middle")

    def svg(self, width: float, height: float, label: str) -> str:
        markers = "".join(
            f'<marker id="{self.marker_id}-{status}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" '
            f'markerHeight="8" orient="auto-start-reverse"><path class="arrowhead {status}" d="M0,0 L10,5 L0,10 z" /></marker>'
            for status in STATUSES
        )
        return (
            f'<svg class="dg" viewBox="0 0 {width:.0f} {height:.0f}" role="img" aria-label="{esc(label)}">'
            f'<defs>{markers}</defs>{"".join(self.parts)}</svg>'
        )


def chain(canvas: Canvas, nodes: list[dict], x: float, y: float, row_h: float) -> float:
    """箱を左から右へ矢印でつなぐ。右端の x を返す。"""
    previous = None
    for node in nodes:
        w, h = node_size(node)
        top = y + (row_h - h) / 2
        if previous is not None:
            status = node.get("edge", status_of(node) if status_of(node) in ("added", "removed") else "same")
            mid = y + row_h / 2
            canvas.edge(f"M{previous + 4:.0f},{mid:.0f} H{x - 4:.0f}", status)
        canvas.node(node, x, top, w, h)
        previous = x + w
        x += w + GAP_X
    return previous or x


def chain_width(nodes: list[dict]) -> float:
    return sum(node_size(n)[0] for n in nodes) + GAP_X * max(0, len(nodes) - 1)


def before_after(spec: dict, canvas: Canvas) -> tuple[float, float]:
    sides = [("変更前", spec["before"]), ("変更後", spec["after"])]
    row_h = max(node_size(n)[1] for _, side in sides for n in side["nodes"])
    panel_w = max(chain_width(side["nodes"]) for _, side in sides) + 40
    for _, side in sides:
        if side.get("note"):
            panel_w = max(panel_w, text_width(side["note"], SMALL) + 40)
    has_note = any(side.get("note") for _, side in sides)
    panel_h = row_h + 60 + (24 if has_note else 0)
    # 左右に並べると横に長すぎて文字が小さくなるときは、上下に並べる
    vertical = panel_w * 2 + 30 > SIDE_BY_SIDE_MAX
    for i, (title, side) in enumerate(sides):
        left = 10 if vertical else 10 + i * (panel_w + 30)
        top = i * (panel_h + 44) if vertical else 0
        canvas.text(left + 10, top + 26, title, "title")
        canvas.parts.append(
            f'<rect class="zone" x="{left:.0f}" y="{top + 38:.0f}" width="{panel_w:.0f}" height="{panel_h:.0f}" rx="12" />'
        )
        start = left + (panel_w - chain_width(side["nodes"])) / 2
        chain(canvas, side["nodes"], start, top + 68, row_h)
        if side.get("note"):
            canvas.text(left + 20, top + 38 + panel_h - 16, side["note"], "small")
    if vertical:
        return panel_w + 20, panel_h * 2 + 44 + 48
    return 20 + panel_w * 2 + 30, 48 + panel_h


def layers(spec: dict, canvas: Canvas) -> tuple[float, float]:
    natural = [sum(node_size(n)[0] for n in layer["nodes"]) + 20 * (len(layer["nodes"]) - 1) for layer in spec["layers"]]
    width = max([420.0, *natural])
    y = 10
    for layer in spec["layers"]:
        canvas.text(10, y + 12, layer["name"], "small")
        y += 20
        count = len(layer["nodes"])
        room = width - 20 * (count - 1)
        needs = [node_size(n)[0] for n in layer["nodes"]]
        # 等分で収まれば等分にし、収まらない箱があれば、必要な幅の比で配る（どの箱も必要な幅を下回らない）
        widths = [room / count] * count if max(needs) <= room / count else [w * room / sum(needs) for w in needs]
        row_h = max(node_size(n)[1] for n in layer["nodes"])
        x = 10
        for node, box_w in zip(layer["nodes"], widths):
            canvas.node(node, x, y, box_w, row_h)
            x += box_w + 20
        y += row_h + GAP_Y
    return width + 20, y - GAP_Y + 14


def flow(spec: dict, canvas: Canvas) -> tuple[float, float, int]:
    nodes = {node["id"]: node for node in spec["nodes"]}
    order = {node_id: i for i, node_id in enumerate(nodes)}
    for edge in spec.get("edges", []):
        for end in ("from", "to"):
            if edge[end] not in nodes:
                raise ValueError(f"edge の {end} に存在しない node: {edge[end]}")
    rank = {node_id: 0 for node_id in nodes}
    for _ in nodes:  # 並び順で前から後ろへ向かう矢印だけで、列を決める
        for edge in spec.get("edges", []):
            if order[edge["from"]] < order[edge["to"]]:
                rank[edge["to"]] = max(rank[edge["to"]], rank[edge["from"]] + 1)
    columns: dict[int, list[str]] = {}
    for node_id in nodes:
        columns.setdefault(rank[node_id], []).append(node_id)
    col_w = {c: max(node_size(nodes[n])[0] for n in ids) for c, ids in columns.items()}
    # 同じ列で戻る矢印は列の右に通り道を作るので、その幅（通り道 + ラベル）を、次の列を置く前に空けておく
    lane_room: dict[int, float] = {}
    for c in columns:
        same = [e for e in spec.get("edges", []) if e["from"] != e["to"] and rank[e["from"]] == rank[e["to"]] == c]
        if same:
            labels = max((text_width(e["label"], SMALL) + 10 for e in same if e.get("label")), default=0)
            lane_room[c] = 18 + 14 * (len(same) - 1) + 4 + labels
    col_h = {c: sum(node_size(nodes[n])[1] for n in ids) + GAP_Y * (len(ids) - 1) for c, ids in columns.items()}
    # 列を飛ばして右へ進む矢印は、間の箱を横切らないよう、すべての箱の上を通す。その通り道の分だけ上を空ける
    skips = [e for e in spec.get("edges", []) if rank[e["to"]] - rank[e["from"]] > 1]
    # 自分自身へ戻る矢印は箱の上に輪で描くので、その分だけ上を空ける
    top = 30 + 22 * len(skips) + (36 if any(e["from"] == e["to"] for e in spec.get("edges", [])) else 0)
    height = max(col_h.values()) + top + 30
    pos: dict[str, tuple[float, float, float, float]] = {}
    x = 10
    for c in sorted(columns):
        y = top + (height - top - 30 - col_h[c]) / 2
        for node_id in columns[c]:
            w, h = node_size(nodes[node_id])
            pos[node_id] = (x + (col_w[c] - w) / 2, y, w, h)
            y += h + GAP_Y
        x += col_w[c] + lane_room.get(c, 0) + GAP_X * 1.6
    width = x - GAP_X * 1.6 + 10
    bottom = max(y + h for _, y, _, h in pos.values())
    col_right = {c: max(pos[n][0] + pos[n][2] for n in ids) for c, ids in columns.items()}
    col_left = {c: min(pos[n][0] for n in ids) for c, ids in columns.items()}
    lowest = {c: ids[-1] for c, ids in columns.items()}  # 列の一番下の箱（その下には何も無い）
    half_gap = GAP_X * 0.8
    back_edges = 0
    skip_edges = 0
    lanes: dict[int, int] = {}
    for edge in spec.get("edges", []):
        a, b = edge["from"], edge["to"]
        ax, ay, aw, ah = pos[a]
        bx, by, bw, bh = pos[b]
        status = status_of(edge)
        if rank[b] - rank[a] > 1:  # 列を飛ばして右へ: 列の間の隙間を上り、すべての箱の上を通って下りる
            skip_edges += 1
            lane_y = 22 + 22 * (skip_edges - 1)
            out_x = col_right[rank[a]] + lane_room.get(rank[a], 0) + GAP_X * 0.5
            in_x = col_left[rank[b]] - GAP_X * 0.5
            sy, ey = ay + ah / 2, by + bh / 2
            path = (
                f"M{ax + aw + 2:.0f},{sy:.0f} L{out_x:.0f},{sy:.0f} L{out_x:.0f},{lane_y:.0f} "
                f"L{in_x:.0f},{lane_y:.0f} L{in_x:.0f},{ey:.0f} L{bx - 4:.0f},{ey:.0f}"
            )
            at = ((out_x + in_x) / 2, lane_y)
        elif rank[b] > rank[a]:  # 隣の列へ
            sx, sy, ex, ey = ax + aw + 2, ay + ah / 2, bx - 4, by + bh / 2
            # 出発する列に戻る矢印の通り道があれば、曲がり目とラベルはその右に置く（ラベル同士を重ねない）
            mx = (max(sx, col_right[rank[a]] + lane_room.get(rank[a], 0)) + ex) / 2
            path = f"M{sx:.0f},{sy:.0f} C{mx:.0f},{sy:.0f} {mx:.0f},{ey:.0f} {ex:.0f},{ey:.0f}"
            at = (mx, (sy + ey) / 2)
        elif a == b:  # 自分自身へ戻る: 箱の上に輪を描く
            left, right = ax + aw * 0.3, ax + aw * 0.7
            path = f"M{left:.0f},{ay - 2:.0f} C{left:.0f},{ay - 34:.0f} {right:.0f},{ay - 34:.0f} {right:.0f},{ay - 6:.0f}"
            at = (ax + aw / 2, ay - 26)
        elif rank[b] == rank[a]:  # 同じ列: 列の右に通り道を作って回す
            c = rank[a]
            lanes[c] = lanes.get(c, 0) + 1
            lane = col_right[c] + 18 + 14 * (lanes[c] - 1)
            sy, ey = ay + ah / 2, by + bh / 2
            path = f"M{ax + aw + 2:.0f},{sy:.0f} C{lane:.0f},{sy:.0f} {lane:.0f},{ey:.0f} {bx + bw + 4:.0f},{ey:.0f}"
            label_w = text_width(edge["label"], SMALL) + 10 if edge.get("label") else 0
            at = (lane + 4 + label_w / 2, (sy + ey) / 2)  # ラベルは通り道の右に出す
            width = max(width, lane + label_w + 20)
        else:  # 左の列へ戻る: すべての箱の下を回る。下に箱がある箱からは、列の間の隙間を通って下りる
            back_edges += 1
            low = bottom + 30 + 22 * (back_edges - 1)
            if lowest[rank[a]] == a:
                start = f"M{ax + aw / 2:.0f},{ay + ah + 2:.0f} L{ax + aw / 2:.0f},{low:.0f}"
                start_x = ax + aw / 2
            else:
                start_x = col_left[rank[a]] - half_gap  # 列でいちばん左の端の外側を下りる（幅の広い箱を横切らない）
                start = f"M{ax - 2:.0f},{ay + ah / 2:.0f} L{start_x:.0f},{ay + ah / 2:.0f} L{start_x:.0f},{low:.0f}"
            if lowest[rank[b]] == b:
                end_x = bx + bw / 2
                end = f"L{end_x:.0f},{low:.0f} L{end_x:.0f},{by + bh + 6:.0f}"
            else:
                end_x = col_right[rank[b]] + half_gap
                end = f"L{end_x:.0f},{low:.0f} L{end_x:.0f},{by + bh / 2:.0f} L{bx + bw + 4:.0f},{by + bh / 2:.0f}"
            path = f"{start} {end}"
            at = ((start_x + end_x) / 2, low - 6)
            height = max(height, low + 20)
        canvas.edge(path, status, edge.get("label"), at)
    for node_id, (nx, ny, nw, nh) in pos.items():
        canvas.node(nodes[node_id], nx, ny, nw, nh)
    return width, height, len(columns)


def group_chip(number: int, links: dict) -> str:
    target = links.get(number)
    if target is None:
        return f'<span class="gnum">{number}</span>'
    return f'<a class="gnum" href="#group-{esc(str(target))}" title="変更グループ {number}">{number}</a>'


def touch_map(spec: dict) -> str:
    """画面を列、層を行にした「どこを触る？」の地図を HTML で作る。"""
    pages = spec.get("pages") or []
    if not pages:
        raise ValueError("touch_map には pages（画面）が要る。brief.json の background.pages に書く")
    index = {page["id"]: i for i, page in enumerate(pages)}
    links = spec.get("group_links", {})
    cols = f'style="--cols:{len(pages)}"'
    head = "".join(
        f'<div class="tm-page"><strong>{esc(page.get("name") or page["id"])}</strong>'
        + (f"<code>{esc(page['url'])}</code>" if page.get("url") else "")
        + "</div>"
        for page in pages
    )
    rows = []
    for row in spec["rows"]:
        items, shared = [], []
        for item in row["items"]:
            status = status_of(item)
            unknown = [p for p in item.get("pages", []) if p not in index]
            if unknown:
                raise ValueError(f"touch_map の pages に無い画面: {unknown}")
            label = "<br />".join(esc(line) for line in item["label"].split("\n"))
            sub = f'<span class="tm-sub">{esc(item["sub"])}</span>' if item.get("sub") else ""
            chips = "".join(group_chip(n, links) for n in item.get("groups", []))
            body = f'<span class="tm-label">{label}</span>{chips}{sub}'
            spots = sorted({index[p] for p in item.get("pages", [])})
            if not spots:  # 全画面共通の部品は、全幅の 1 行に横に並べる
                shared.append(f'<div class="tm-item {status}">{body}</div>')
                continue
            # 隣り合う画面はまたいで 1 つに、離れた画面にはそれぞれ置く（間の画面をまたがない）
            runs = [[spots[0], spots[0]]]
            for spot in spots[1:]:
                if spot == runs[-1][1] + 1:
                    runs[-1][1] = spot
                else:
                    runs.append([spot, spot])
            for start, end in runs:
                items.append(f'<div class="tm-item {status}" style="grid-column:{start + 1} / {end + 2}">{body}</div>')
        if shared:
            items.append(f'<div class="tm-shared" style="grid-column:1 / -1"><span class="tm-note">全画面共通</span>{"".join(shared)}</div>')
        rows.append(f'<div class="tm-row"><div class="tm-layer">{esc(row["name"])}</div><div class="tm-cells" {cols}>{"".join(items)}</div></div>')
    return (
        f'<div class="touch-map"><div class="tm-row tm-head"><div class="tm-layer">画面</div>'
        f'<div class="tm-cells" {cols}>{head}</div></div>{"".join(rows)}</div>'
    )


def render_picture(spec: dict, index: int) -> str:
    canvas = Canvas(f"arrow-{index}")
    kind = spec.get("type")
    wide_default = False
    body = None
    if kind == "touch_map":
        body = touch_map(spec)
        wide_default = True
    elif kind == "before_after":
        width, height = before_after(spec, canvas)
        wide_default = True
    elif kind == "layers":
        width, height = layers(spec, canvas)
    elif kind == "flow":
        width, height, column_count = flow(spec, canvas)
        wide_default = column_count >= 4
    else:
        raise ValueError(f"絵の type は before_after / touch_map / flow / layers のどれか: {kind}")
    wide = " wide" if spec.get("wide", wide_default) else ""
    lead = f'<p class="lead">{esc(spec["lead"])}</p>' if spec.get("lead") else ""
    caption = f"<figcaption>{esc(spec['caption'])}</figcaption>" if spec.get("caption") else ""
    return (
        f'<figure class="picture{wide}"><h3>{esc(spec["title"])}</h3>{lead}'
        f'{body if body is not None else canvas.svg(width, height, spec["title"])}{caption}</figure>'
    )
