"""agent-lessons のスクリプトが共有する、ファイルの場所・frontmatter の読み書き・glob 判定。

教訓（lessons/）と観察（inbox/）は YAML frontmatter 付きの Markdown。PyYAML に頼らず標準ライブラリだけで
動かすため、このリポジトリで使う形（スカラー・インラインのリスト・ブロックのリスト）だけを扱う。
Basic Memory が足す `permalink` などの未知のキーもそのまま残す。
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# 場所は固定。dotfiles は config/ を XDG_CONFIG_HOME に関係なく ~/.config へ配るため、XDG_* には合わせない
LESSONS_DIR = Path.home() / ".local/share/agent-lessons"
TARGETS_DIR = Path.home() / ".config/agent-lessons"
SOURCES = ("received", "given", "team")
_SEG = r"(?!\.\.?(?:/|$))[\w.-]+"  # . と .. は通さない
SCOPE_KEY = re.compile(rf"global|{_SEG}/{_SEG}(?:/{_SEG})?")

# 教訓・観察の形式のバージョン。形式を変えたら 1 上げ、migrate.py の MIGRATIONS に前の版からの移行を足す。
# 書き込むスクリプトは、古い版のファイルが残っていると止まる（混ざった形式に書き足さないため）。
SCHEMA_VERSION = 1

# 教訓の status。注入されるのは active だけ（ruled は仕組みに移したので注入しない）
STATUSES = ("candidate", "active", "ruled", "retired")
# 教訓の `## Patterns`（よく出た形）に残す数。超えたら古いものから落とす（push 前に読む量を抑えるため）
MAX_PATTERNS = 8

# 観察・教訓の文章は日本語で書く。コード・識別子・固有名詞は `` で囲めば原文のままでよいので、その中は見ない
_HANGUL = re.compile(r"[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]")
_KANA = re.compile(r"[\u3040-\u30ff]")
_CODE = re.compile(r"`[^`]*`")

FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n?(.*)\Z", re.S)


def _scalar(text: str) -> object:
    text = text.strip()
    if text == "":
        return None
    if text[0] in "\"'" and text[-1] == text[0]:
        return text[1:-1] if text[0] == "'" else json.loads(text)
    if text in ("true", "false"):
        return text == "true"
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    return text


def _inline_list(text: str) -> list:
    inner = text.strip()[1:-1].strip()
    if not inner:
        return []
    items, buf, quote = [], "", None
    for ch in inner:
        if quote:
            buf += ch
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            buf += ch
        elif ch == ",":
            items.append(_scalar(buf))
            buf = ""
        else:
            buf += ch
    items.append(_scalar(buf))
    return items


def _strip_comment(v: str) -> str:
    """引用符の外にある ` #` 以降をコメントとして落とす。"""
    quote = None
    for i, ch in enumerate(v):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#" and (i == 0 or v[i - 1] in " \t"):
            return v[:i].strip()
    return v.strip()


def parse(text: str) -> tuple[dict, str]:
    """frontmatter と本文に分ける。frontmatter が無ければ ({}, text)。"""
    m = FRONTMATTER.match(text)
    if not m:
        return {}, text
    meta: dict = {}
    key = None
    for line in m.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.lstrip().startswith("- ") and key is not None:
            if not isinstance(meta[key], list):
                meta[key] = []
            meta[key].append(_scalar(_strip_comment(line.split("- ", 1)[1])))
            continue
        k, _, v = line.partition(":")
        key = k.strip()
        v = _strip_comment(v)
        meta[key] = _inline_list(v) if v.startswith("[") else _scalar(v)
    return meta, m.group(2)


def _dump_value(v: object) -> str:
    if isinstance(v, list):
        return "[" + ", ".join(_dump_value(x) for x in v) + "]"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if v is None:
        return ""
    s = str(v)
    if re.fullmatch(r"[\w./@+-]+", s) and s not in ("true", "false") and not re.fullmatch(r"-?\d+", s):
        return s
    return json.dumps(s, ensure_ascii=False)


def dump(meta: dict, body: str) -> str:
    lines = [f"{k}: {_dump_value(v)}".rstrip() for k, v in meta.items()]
    return "---\n" + "\n".join(lines) + "\n---\n" + body.lstrip("\n")


def read(path: Path) -> tuple[dict, str]:
    return parse(path.read_text(encoding="utf-8"))


def write(path: Path, meta: dict, body: str) -> None:
    """常に今の版として書く。古い版のファイルは check_schema(strict=True) で先に止めておくこと。"""
    meta = {"schema_version": SCHEMA_VERSION, **{k: v for k, v in meta.items() if k != "schema_version"}}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dump(meta, body), encoding="utf-8")


def version_of(meta: dict) -> int:
    """schema_version が無いファイルは版を付ける前の形式（0）。"""
    return int(meta.get("schema_version") or 0)


def note_files() -> list[Path]:
    return sorted(p for sub in ("inbox", "lessons", "archived") for p in (LESSONS_DIR / sub).rglob("*.md"))


def check_schema(strict: bool) -> bool:
    """新しい版のファイルがあれば止める（この dotfiles が古い）。古い版は strict なら止め、そうでなければ警告だけ出す。
    すべて今の版なら True。"""
    versions = {p: version_of(read(p)[0]) for p in note_files()}
    newer = [p for p, v in versions.items() if v > SCHEMA_VERSION]
    older = [p for p, v in versions.items() if v < SCHEMA_VERSION]
    if newer:
        sys.exit(
            f"error: schema_version {SCHEMA_VERSION} より新しい形式のファイルが {len(newer)} 件ある"
            f"（例: {newer[0]}）。dotfiles を更新して rulesync で skill を配り直す"
        )
    if older:
        msg = f"schema_version {SCHEMA_VERSION} より古い形式のファイルが {len(older)} 件ある。migrate.py で移行する"
        if strict:
            sys.exit(f"error: {msg}")
        print(f"warning: {msg}", file=sys.stderr)
    return not older


def sections(body: str) -> dict[str, str]:
    """`## 見出し` ごとの本文。"""
    out: dict[str, str] = {}
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", body, re.M | re.S):
        out[m.group(1).strip()] = m.group(2).strip()
    return out


def bullets(text: str) -> list[str]:
    """`- ` で始まる行（`## Patterns` の 1 件ずつなど）。"""
    return [ln.strip() for ln in text.splitlines() if ln.startswith("- ")]


def set_section(body: str, name: str, content: str, before: str | None = None) -> str:
    """`## name` の本文を content にする。無ければ `## before` の前に（それも無ければ末尾に）足す。"""
    block = f"## {name}\n{content.strip()}\n\n"
    m = re.search(rf"^## {re.escape(name)}\n.*?(?=^## |\Z)", body, re.M | re.S)
    if m:
        body = body[: m.start()] + block + body[m.end() :]
    elif before and (m := re.search(rf"^## {re.escape(before)}\n", body, re.M)):
        body = body[: m.start()] + block + body[m.start() :]
    else:
        body = body.rstrip() + "\n\n" + block
    return re.sub(r"\n{3,}", "\n\n", body).rstrip() + "\n"


def glob_regex(pattern: str) -> re.Pattern:
    """`**` はディレクトリをまたぐ、`*` はまたがない glob を正規表現にする。"""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def normalize_globs(globs: list | None) -> list[str]:
    """モデルが付けがちな囲みの引用符を外し、`/` を含まない glob は入れ子のパスにも効くよう `**/` を付ける。"""
    out = []
    for g in globs or []:
        g = str(g).strip().strip("\"'").strip()
        if g:
            out.append(g if "/" in g else f"**/{g}")
    return sorted(set(out))


def matches(globs: list | None, paths: list[str]) -> bool:
    """globs が空なら常に一致。paths が空なら（変更ファイルを指定しないなら）一致とみなす。"""
    if not globs or not paths:
        return True
    regs = [glob_regex(g) for g in globs]
    return any(r.match(p) for r in regs for p in paths)


def scope_keys(cwd: str | os.PathLike = ".") -> list[str]:
    """`origin` の URL から、作業中のリポジトリに効く scope_key を返す（global・owner・repo）。"""
    try:
        remote = subprocess.run(
            ["git", "-C", str(cwd), "remote", "get-url", "origin"], capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ["global"]
    slug = re.sub(r"^[a-z+]+://", "", remote)
    slug = re.sub(r"^[^@/]*@", "", slug)
    slug = re.sub(r"^([^/:]+):", r"\1/", slug)
    slug = re.sub(r"\.git$", "", slug)
    if re.fullmatch(r"[^/]+/[^/]+/[^/]+", slug):
        return ["global", slug.rsplit("/", 1)[0], slug]
    return ["global"]


def inside(rel: str, sub: str) -> Path | None:
    """plan などに書かれた相対パスを、LESSONS_DIR/<sub> の中にあるときだけ絶対パスにする（外を書き換えないため）。"""
    path = (LESSONS_DIR / rel).resolve()
    return path if path.is_relative_to((LESSONS_DIR / sub).resolve()) else None


def lesson_files() -> list[Path]:
    return sorted((LESSONS_DIR / "lessons").rglob("*.md"))


def language_error(text: str) -> str | None:
    """日本語の文章でなければ理由を返す。かなの有無で見る（漢字だけでは中国語と区別できないため）。"""
    prose = _CODE.sub("", str(text))
    if _HANGUL.search(prose):
        return "ハングルが含まれる"
    if re.search(r"[^\W\d_]", prose) and not _KANA.search(prose):
        return "日本語（ひらがな・カタカナ）が含まれない"
    return None
