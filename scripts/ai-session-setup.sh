#!/bin/bash
set -euo pipefail

# Claude Code / Codex は SessionStart の stdout をコンテキストに取り込むため、ログは stderr に出す。
exec 1>&2

cd "$(dirname "$0")/.."

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export PATH=\"$HOME/.local/bin:$HOME/.local/share/mise/shims:\$PATH\"" >>"$CLAUDE_ENV_FILE"
fi

# mise.jdx.dev（リリース一覧）は Claude Code のクラウド環境で拒否されるため、バージョンを固定して GitHub から取得する。
if ! command -v mise >/dev/null 2>&1; then
	MISE_VERSION="$(awk -F'"' '/^min_version/ { print $2; exit }' mise.toml)"
	curl -fsSL https://mise.run | MISE_VERSION="$MISE_VERSION" MISE_INSTALL_FROM_GITHUB=1 sh
fi

# Claude Code のクラウド環境の GitHub API はセッションのリポジトリ以外を拒否する。token があると mise は
# mise.lock の url_api（GitHub API）を使うため、token を外して url（直接ダウンロード）を使わせる。
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
	unset GITHUB_TOKEN GH_TOKEN
fi
mise trust --yes
mise install --yes
mise exec -- lefthook install
