#!/bin/bash
set -euo pipefail
[ "$(uname)" != "Darwin" ] && exit

if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
else
  echo "mise is already installed"
fi
