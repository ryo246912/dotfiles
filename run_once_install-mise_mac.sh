#!/bin/bash
[ "$(uname)" != "Darwin" ] && exit

# mise 自身は mise task 化できない（`mise run` を使うには mise が既に必要になり
# 自己矛盾するため）。post-apply hook が mise を呼べるよう、chezmoi の run_once として
# mise 非依存に導入する（run_once_install-packages_windows.sh の mise 導入と同じ方式）。
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
else
  echo "mise is already installed"
fi
