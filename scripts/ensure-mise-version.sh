#!/bin/bash
# mise.toml の min_version を満たすよう mise 本体を self-update する。
# `mise bootstrap` 等の通常コマンドは config を読む際に min_version 未満だと
# 実行を拒否するため、この安全弁自体を mise の hook（[bootstrap.hooks.*]）の
# 中には置けない（未更新の mise では hook まで到達できない）。そのため
# `mise bootstrap` を呼ぶ前に、config を読まずに実行できるこのスクリプトを
# 独立して呼ぶ運用にしている。
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required_mise_version=$(awk -F'"' '/^[[:space:]]*min_version[[:space:]]*=/ { print $2; exit }' "$script_dir/../mise.toml")
if [ -z "$required_mise_version" ]; then
  echo "error: mise.toml から min_version を取得できません" >&2
  exit 1
fi
echo "Ensuring mise $required_mise_version is installed..."
if ! MISE_NO_CONFIG=1 mise self-update --yes "$required_mise_version"; then
  cat >&2 <<EOF
error: 'mise self-update' に失敗しました。
brew/apt/scoop 等のパッケージマネージャーで導入した mise は self-update を拒否するため
これが原因の可能性があります。その場合はパッケージマネージャー側で更新してください
（例: brew upgrade mise / sudo apt update && sudo apt upgrade mise）。
更新後、このスクリプトを再実行して min_version ($required_mise_version) 以上になったことを確認してください。
EOF
  exit 1
fi
