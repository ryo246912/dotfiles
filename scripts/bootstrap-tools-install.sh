#!/bin/bash
set -euo pipefail

# gh と mise の tool は shim 経由なので、mise bootstrap の hook の PATH には入っていない。
if [ "$(uname)" = "Darwin" ]; then
	export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"
else
	export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
fi

mise install --jobs=1 aqua:cli/cli || true
if ! gh auth token >/dev/null 2>&1; then
	gh auth login --scopes 'project' || true
fi
# token なしの install は GitHub API の rate limit で途中から失敗するため、続行せずに止める。
github_token=$(gh auth token 2>/dev/null || true)
if [ -z "$github_token" ]; then
	echo "error: gh 未ログインのため中断します。'gh auth login --scopes project' 後に再実行してください" >&2
	exit 1
fi

# mise に組み込まれた aube（npm backend）は、aube CLI と違い RLIMIT_NOFILE を引き上げないため、
# macOS の既定値（256）のままだと npm:renovate 等で "Too many open files (os error 24)" になる。
nofile=$(ulimit -n)
if [ "$nofile" != unlimited ] && [ "$nofile" -lt 10240 ]; then
	ulimit -n 10240 2>/dev/null || true
fi

# `mise install` は既存の lockfile を更新するだけで新規作成しない。lockfile が無いと、
# 後続の MISE_LOCKED=1 の task から apm・rulesync・python3 などを解決できない。
[ -e "$HOME/.config/mise/mise.lock" ] || : >"$HOME/.config/mise/mise.lock"

echo "Running mise install..."
GITHUB_TOKEN=$github_token mise install --jobs=2
