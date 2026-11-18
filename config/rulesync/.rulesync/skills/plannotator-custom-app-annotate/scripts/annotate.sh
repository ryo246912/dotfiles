#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )); then
    printf 'Usage: bash %s <app-url> <port> [port ...]\n' "$0" >&2
    exit 2
fi

app_url=$1
shift
tunnel_script="$HOME/.config/devcontainer/scripts/ensure-plannotator-tunnel"

command -v plannotator >/dev/null || {
    printf 'plannotator is required.\n' >&2
    exit 1
}

for port in "$@"; do
    "$tunnel_script" "$port"
done

exec plannotator annotate "$app_url" --app
