#!/bin/bash
# git push / gh pr create の直前に CodeRabbit CLI でローカルレビューする（rulesync の各 CLI の PreToolUse hook から呼ぶ）。
# .coderabbit.yaml があり、coderabbit が PATH にあるときだけ動く。
# それ以外（ホストなど CLI 未導入の環境を含む）は何もしない。
# HEAD ごとに 1 回だけ、レビュー結果を stderr に出して exit 2 で実行をブロックする（agent に結果が渡る）。
# 修正してコミットするか、対応不要ならもう一度実行すれば通る。CLI の失敗は止めない。
set -uo pipefail

# PreToolUse の matcher は tool 名に対するものなので、コマンドは stdin で判定する。
# 単独のコマンドと「cd repo && git push」などを対象にする。
# Codex も tool_input を渡す（exec_command は cmd、shell_command は command）。
# Copilot の toolArgs はオブジェクトと JSON 文字列の両方を受け付ける。
cmd=$(jq -er '
    (.tool_input // .toolArgs // empty)
    | if type == "string" then fromjson else . end
    | (.command // .cmd // empty)
    | select(type == "string")
' 2>/dev/null) || exit 0
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
# sbx custom secret の場合はプレースホルダー。実キーへの置換はホストのプロキシが行う。
review_args=(review --committed)
if [ -n "${CODERABBIT_API_KEY:-}" ]; then
    review_args+=(--api-key "$CODERABBIT_API_KEY")
fi
output=$(coderabbit "${review_args[@]}" 2>&1) || exit 0
echo "$head_sha" >"$marker"
echo "$output" >&2
exit 2
