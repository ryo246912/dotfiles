#!/bin/bash
# git push の直前に CodeRabbit CLI でローカルレビューする（claude/settings.json の PreToolUse hook から呼ぶ）。
# .coderabbit.yaml があり enabled: false でなく、coderabbit が PATH にあるときだけ動く。それ以外は何もしない。
# HEAD ごとに 1 回だけ、レビュー結果を stderr に出して exit 2 で push をブロックする（Claude に結果が渡る）。
# 修正してコミットするか、対応不要ならもう一度 push すれば通る。CLI の失敗は push を止めない。
set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 0
config=.coderabbit.yaml
[ -f "$config" ] || exit 0
grep -Eq '^[[:space:]]+enabled:[[:space:]]*false' "$config" && exit 0
command -v coderabbit >/dev/null 2>&1 || exit 0

marker="$(git rev-parse --git-dir)/coderabbit-reviewed"
head_sha=$(git rev-parse HEAD)
[ "$(cat "$marker" 2>/dev/null)" = "$head_sha" ] && exit 0

output=$(coderabbit review --plain --type committed 2>&1) || exit 0
echo "$head_sha" >"$marker"
echo "$output" >&2
exit 2
