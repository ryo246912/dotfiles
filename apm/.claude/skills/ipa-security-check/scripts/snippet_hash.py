#!/usr/bin/env python3
"""
findings JSON の各要素に `snippet_hash` を付与する。

triage_state.md の仕様に従う:
- file: リポジトリルートからの相対パス (区切り文字は "/" に統一)
- code_snippet 正規化:
    1. 改行を \\n に統一
    2. 前後の空白行を除去
    3. 各行末空白を除去
    4. 連続空白 (スペース/タブ) を 1 つに圧縮
    5. 行頭インデントは保持しない
    6. 大文字小文字は保持
- key  = rule_id + "\\n" + file_normalized + "\\n" + code_normalized
- hash = "sha256:" + sha256(key).hexdigest()[:16]

CLI:
    python3 snippet_hash.py <findings_in.json> <findings_out.json>

`-` を渡すと stdin / stdout でも扱える:
    cat findings.json | python3 snippet_hash.py - -
"""
from __future__ import annotations

import hashlib
import json
import re
import sys


def normalize_path(p: str) -> str:
    return p.replace("\\", "/")


def normalize_code(s: str) -> str:
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    lines = [re.sub(r"\s+", " ", line).strip() for line in s.split("\n")]
    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines)


def snippet_hash(rule_id: str, file: str, code: str) -> str:
    key = rule_id + "\n" + normalize_path(file) + "\n" + normalize_code(code)
    return "sha256:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


def annotate(findings: list) -> list:
    for f in findings:
        f["snippet_hash"] = snippet_hash(f["rule_id"], f["file"], f["code_snippet"])
    return findings


def _read(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    with open(path, encoding="utf-8") as fp:
        return fp.read()


def _write(path: str, text: str) -> None:
    if path == "-":
        sys.stdout.write(text)
        return
    with open(path, "w", encoding="utf-8") as fp:
        fp.write(text)


def main(argv: list) -> int:
    if len(argv) != 3:
        sys.stderr.write("usage: snippet_hash.py <in.json> <out.json>\n")
        return 2
    findings = json.loads(_read(argv[1]))
    annotate(findings)
    _write(argv[2], json.dumps(findings, ensure_ascii=False, indent=2))
    sys.stderr.write(f"[snippet_hash] {len(findings)} findings annotated\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
