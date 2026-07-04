#!/bin/bash
# coderabbit-review-hook.sh
#
# 概要:
#   Claude Code / Codex CLI の Stop hook として呼び出され、ワーキングツリーの
#   未コミット差分を CodeRabbit CLI (`coderabbit --plain`) でレビューする。
#   指摘があれば stop をブロックしてエージェントに差し戻す。
#   (Claude Code / Codex CLI とも、Stop hook で exit code 2 + stderr を返すと
#    stderr の内容がエージェントに渡され、stop がブロックされる)
#   手順の詳細は coderabbit skill の「4. コミット不要のローカル自動修正ループ」参照。
#
# 注意:
#   - 無限ループ防止のため、stdin の stop_hook_active が true なら何もせず終了する
#     (直前の stop がこの hook でブロックされた継続呼び出しの場合、再ブロックしない)
#   - coderabbit 未インストール / git リポジトリ外 / 差分なし の場合は何もしない
#
set -euo pipefail

input="$(cat 2>/dev/null || true)"

case "$input" in
*'"stop_hook_active":true'* | *'"stop_hook_active": true'*)
	exit 0
	;;
esac

command -v coderabbit >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

if git diff --quiet && git diff --cached --quiet; then
	exit 0
fi

output="$(coderabbit --plain 2>/dev/null || true)"

if [ -z "$output" ]; then
	exit 0
fi

{
	echo "CodeRabbit CLI が未コミットの変更に対して指摘を検出しました。内容を確認し、妥当な指摘は修正してください。"
	echo
	echo "$output"
} >&2

exit 2
