#!/bin/bash
# coderabbit-review-hook.sh
#
# 概要:
#   Claude Code の PreToolUse(Bash) hook。`git push` / `gh pr create` の直前に CodeRabbit CLI で
#   ローカルレビューを走らせ、PR 前に指摘へ対応できるようにする。
#
# 実行条件（すべて満たすときだけ動き、満たさなければ何もせず exit 0）:
#   - コマンドが `git push` または `gh pr create`
#   - リポジトリ直下に .coderabbit.yaml（.yml）があり、reviews.auto_review.enabled が false でない
#   - coderabbit（または cr）CLI が PATH にある
#   - CODERABBIT_LOCAL_REVIEW=0 で無効化されていない
#
# 動作:
#   - デフォルトブランチとの差分（コミット済み）をレビューする。
#   - HEAD ごとに 1 回だけ実行する。指摘があればその 1 回は push をブロックして出力を Claude に返し、
#     修正して新しいコミットを作ると再レビューされる。同じ HEAD で再実行した push はそのまま通る。
#   - CLI の失敗（未ログイン・ネットワーク・タイムアウト）は push を止めない。
set -uo pipefail

[ "${CODERABBIT_LOCAL_REVIEW:-1}" = "0" ] && exit 0

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

# `git push` / `gh pr create` を含むときだけ対象（`git -C x push` や `&&` 連結も拾う）
if ! grep -Eq '(^|[;&|[:space:]])(git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]-][^[:space:]]*)?)*[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create)([[:space:]]|$)' <<<"$command"; then
	exit 0
fi

cd "${cwd:-.}" 2>/dev/null || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

config=""
for f in .coderabbit.yaml .coderabbit.yml; do
	[ -f "$f" ] && config=$f && break
done
[ -n "$config" ] || exit 0

# レビュー有効判定: reviews.auto_review.enabled が false のときだけ無効
if command -v yq >/dev/null 2>&1; then
	# `// true` は false も置き換えてしまうため使わない（未設定は null で、有効扱い）
	enabled=$(yq -r '.reviews.auto_review.enabled' "$config" 2>/dev/null || echo true)
	[ "$enabled" = "false" ] && exit 0
fi

cli=$(command -v coderabbit || command -v cr || true)
[ -n "$cli" ] || exit 0

base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
base=${base:-main}
git rev-parse --verify --quiet "origin/$base" >/dev/null || exit 0
[ -n "$(git rev-list "origin/$base..HEAD" 2>/dev/null | head -1)" ] || exit 0

head_sha=$(git rev-parse HEAD)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/coderabbit-review-hook"
mkdir -p "$state_dir"
key=$(printf '%s' "$root" | cksum | cut -d' ' -f1)
marker="$state_dir/$key.sha"
[ "$(cat "$marker" 2>/dev/null)" = "$head_sha" ] && exit 0

echo "CodeRabbit CLI でローカルレビュー中（base: origin/$base）..." >&2
if ! output=$(timeout "${CODERABBIT_LOCAL_REVIEW_TIMEOUT:-540}" "$cli" review --plain --type committed --base "$base" 2>&1); then
	echo "CodeRabbit CLI が失敗したためレビューをスキップします: $(tail -n 3 <<<"$output")" >&2
	exit 0
fi

printf '%s' "$head_sha" >"$marker"
[ -n "${output//[[:space:]]/}" ] || exit 0

reason=$(printf 'CodeRabbit ローカルレビューの結果です。対応が必要な指摘は修正してコミットしてから再度実行してください。対応不要なら同じコマンドをもう一度実行すれば push / PR 作成できます。\n\n%s' "$output")
jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
