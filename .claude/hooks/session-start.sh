#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# クラウド環境の GitHub API はセッションのリポジトリ以外を拒否するため、attestation 検証は
# 行わず、mise.lock に記録した URL とチェックサムだけでインストールする。
cat >>"$CLAUDE_ENV_FILE" <<ENV
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:\$PATH"
export MISE_AQUA_GITHUB_ATTESTATIONS=0
export MISE_GITHUB_GITHUB_ATTESTATIONS=0
ENV
# shellcheck disable=SC1090
source "$CLAUDE_ENV_FILE"

# mise.jdx.dev（リリース一覧）もネットワークポリシーで拒否されるため、バージョンを固定して GitHub から取得する。
if ! command -v mise >/dev/null 2>&1; then
	MISE_VERSION="$(awk -F'"' '/^min_version/ { print $2; exit }' mise.toml)"
	curl -fsSL https://mise.run | MISE_VERSION="$MISE_VERSION" MISE_INSTALL_FROM_GITHUB=1 sh
fi
mise trust --yes
mise install --yes
lefthook install
