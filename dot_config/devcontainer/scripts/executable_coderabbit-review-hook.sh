#!/bin/bash
# coderabbit-review-hook.sh
#
# 概要:
#   Claude Code / Codex CLI の Stop hook として呼び出され、ワーキングツリーの
#   未コミット変更（未追跡ファイル含む）を CodeRabbit CLI (`coderabbit --plain`)
#   でレビューする。指摘があれば stop をブロックしてエージェントに差し戻す。
#   (Claude Code / Codex CLI とも、Stop hook で exit code 2 + stderr を返すと
#    stderr の内容がエージェントに渡され、stop がブロックされる)
#   手順の詳細は review-coderabbit skill の「4. コミット不要のローカル自動修正ループ」参照。
#
# 注意:
#   - 無限ループ防止のため、stdin の stop_hook_active が true なら何もせず終了する
#     (直前の stop がこの hook でブロックされた継続呼び出しの場合、再ブロックしない)
#   - coderabbit 未インストール / git リポジトリ外 / 変更なし の場合は何もしない
#   - coderabbit の実行自体が失敗した場合 (認証切れ・ネットワーク障害など) は
#     stderr にログを残して exit 0 (stop はブロックしない)
#
set -euo pipefail

readonly REVIEW_TIMEOUT_SECONDS=150

input="$(cat 2>/dev/null || true)"

if command -v jq >/dev/null 2>&1; then
	if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
		exit 0
	fi
elif printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
	exit 0
fi

command -v coderabbit >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 追跡ファイルの変更 (staged/unstaged) と未追跡ファイルをまとめて検知
if [ -z "$(git status --porcelain --untracked-files=all)" ]; then
	exit 0
fi

review_cmd=(coderabbit --plain)
if command -v timeout >/dev/null 2>&1; then
	review_cmd=(timeout "$REVIEW_TIMEOUT_SECONDS" "${review_cmd[@]}")
fi

stderr_file="$(mktemp)"
trap 'rm -f "$stderr_file"' EXIT

set +e
output="$("${review_cmd[@]}" 2>"$stderr_file")"
review_status=$?
set -e

if [ "$review_status" -ne 0 ]; then
	{
		echo "coderabbit-review-hook: coderabbit --plain failed (exit ${review_status}); skipping review"
		tail -n 5 "$stderr_file"
	} >&2
	exit 0
fi

if [ -z "$output" ]; then
	exit 0
fi

{
	echo "CodeRabbit CLI が未コミットの変更に対して指摘を検出しました。内容を確認し、妥当な指摘は修正してください。"
	echo
	echo "$output"
} >&2

exit 2
