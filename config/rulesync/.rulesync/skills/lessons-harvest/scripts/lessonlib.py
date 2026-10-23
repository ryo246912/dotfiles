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
from pathlib import Path

LESSONS_DIR = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "agent-lessons"
TARGETS_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "agent-lessons"

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
            meta[key].append(_scalar(line.split("- ", 1)[1]))
            continue
        k, _, v = line.partition(":")
        key = k.strip()
        v = v.split(" #", 1)[0].strip()
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
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dump(meta, body), encoding="utf-8")


def sections(body: str) -> dict[str, str]:
    """`## 見出し` ごとの本文。"""
    out: dict[str, str] = {}
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", body, re.M | re.S):
        out[m.group(1).strip()] = m.group(2).strip()
    return out


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


def lesson_files() -> list[Path]:
    return sorted((LESSONS_DIR / "lessons").rglob("*.md"))
