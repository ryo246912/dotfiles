#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

cat >>"$CLAUDE_ENV_FILE" <<ENV
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:\$PATH"
ENV
# shellcheck disable=SC1090
source "$CLAUDE_ENV_FILE"

# クローン直後は git hook が未インストールで lefthook の post-checkout が走らないため、
# lefthook を動かすのに必要な mise と lefthook だけ入れ、残りのセットアップは post-checkout に任せる。
if ! command -v mise >/dev/null 2>&1; then
	MISE_VERSION="$(awk -F'"' '/^min_version/ { print $2; exit }' mise.toml)"
	curl -fsSL https://mise.run | MISE_VERSION="$MISE_VERSION" MISE_INSTALL_FROM_GITHUB=1 sh
fi
mise trust --yes
env -u GITHUB_TOKEN -u GH_TOKEN mise install --yes aqua:evilmartians/lefthook
AI_AGENT="${AI_AGENT:-1}" mise exec -- lefthook run post-checkout
