#!/bin/sh
set -eu

# This script is intentionally independent of mise config loading. It migrates
# existing hosts before the post-apply hook reads a config with a newer
# min_version, and it also replaces package-managed builds with the official
# binary when self-update is unavailable.
if command -v mise >/dev/null 2>&1; then
  mise self-update --yes --no-plugins && exit 0
fi

curl -fsSL https://mise.run | sh
