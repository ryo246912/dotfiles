#!/bin/bash
# git push / gh pr create の直前に CodeRabbit CLI でローカルレビューする（claude/settings.json の PreToolUse hook から呼ぶ）。
# .coderabbit.yaml があり、coderabbit が PATH にあるときだけ動く。
# それ以外（ホストなど CLI 未導入の環境を含む）は何もしない。
# HEAD ごとに 1 回だけ、レビュー結果を stderr に出して exit 2 で実行をブロックする（Claude に結果が渡る）。
# 修正してコミットするか、対応不要ならもう一度実行すれば通る。CLI の失敗は止めない。
set -uo pipefail

# PreToolUse の matcher は tool 名に対するものなので、コマンドは stdin で判定する。
# 単独のコマンドと「cd repo && git push」などを対象にする。
cmd=$(jq -er '.tool_input.command | select(type == "string")' 2>/dev/null) || exit 0
target='(^|&&)[[:space:]]*(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create)([[:space:]]|$)'
[[ "$cmd" =~ $target ]] || exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 0
config=.coderabbit.yaml
[ -f "$config" ] || exit 0

command -v coderabbit >/dev/null 2>&1 || exit 0

marker="$(git rev-parse --git-dir)/coderabbit-reviewed"
head_sha=$(git rev-parse HEAD)
[ "$(cat "$marker" 2>/dev/null)" = "$head_sha" ] && exit 0

echo "Reviewing with CodeRabbit CLI..." >&2
output=$(coderabbit review --committed 2>&1) || exit 0
echo "$head_sha" >"$marker"
echo "$output" >&2
exit 2
