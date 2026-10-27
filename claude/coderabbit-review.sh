#!/bin/bash
# git push / gh pr create の直前に CodeRabbit CLI でローカルレビューする（claude/settings.json の PreToolUse hook から呼ぶ）。
# .coderabbit.yaml があり reviews.auto_review.enabled が false でなく、coderabbit が PATH にあるときだけ動く。
# それ以外（ホストなど CLI 未導入の環境を含む）は何もしない。
# HEAD ごとに 1 回だけ、レビュー結果を stderr に出して exit 2 で実行をブロックする（Claude に結果が渡る）。
# 修正してコミットするか、対応不要ならもう一度実行すれば通る。CLI の失敗は止めない。
set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 0
config=.coderabbit.yaml
[ -f "$config" ] || exit 0

# auto_review ブロック内の `enabled: false` だけを見る（他の tools.*.enabled などは無視する）。
auto_review_disabled=$(awk '
	match($0, /^[[:space:]]*/) { indent = RLENGTH }
	in_block && $0 !~ /^[[:space:]]*(#|$)/ && indent <= block_indent { in_block = 0 }
	in_block && /^[[:space:]]*enabled:[[:space:]]*false([[:space:]]|#|$)/ { print "yes"; exit }
	/^[[:space:]]*auto_review:/ { in_block = 1; block_indent = indent }
' "$config")
[ -n "$auto_review_disabled" ] && exit 0
command -v coderabbit >/dev/null 2>&1 || exit 0

marker="$(git rev-parse --git-dir)/coderabbit-reviewed"
head_sha=$(git rev-parse HEAD)
[ "$(cat "$marker" 2>/dev/null)" = "$head_sha" ] && exit 0

output=$(coderabbit review --committed 2>&1) || exit 0
echo "$head_sha" >"$marker"
echo "$output" >&2
exit 2
