#!/bin/bash
set -euo pipefail
[ "$(uname)" != "Darwin" ] && exit

# mise 自身は mise task 化できない（`mise run` を使うには mise が既に必要になり
# 自己矛盾するため）。post-apply hook が mise を呼べるよう、chezmoi の run_once として
# mise 非依存に導入する（run_once_install-packages_windows.sh の mise 導入と同じ方式）。
# pipefail が無いと curl 失敗時も `sh` が空 stdin で exit 0 し、chezmoi が run_once を
# 成功扱いで記録してしまい mise 未導入のまま再試行されなくなる。
if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
else
  echo "mise is already installed"
fi
