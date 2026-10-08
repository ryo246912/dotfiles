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

# mise.jdx.dev（リリース一覧）はネットワークポリシーで拒否されるため、バージョンを固定して GitHub から取得する。
if ! command -v mise >/dev/null 2>&1; then
	MISE_VERSION="$(awk -F'"' '/^min_version/ { print $2; exit }' mise.toml)"
	curl -fsSL https://mise.run | MISE_VERSION="$MISE_VERSION" MISE_INSTALL_FROM_GITHUB=1 sh
fi
mise trust --yes
# クラウド環境の GitHub API はセッションのリポジトリ以外を拒否する。token があると mise は mise.lock の
# url_api（GitHub API）を使うため、token を外して url（直接ダウンロード）を使わせる。
env -u GITHUB_TOKEN -u GH_TOKEN mise install --yes
lefthook install
