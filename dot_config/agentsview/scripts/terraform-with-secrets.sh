#!/usr/bin/env bash
set -euo pipefail

for command in fnox terraform; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

for name in \
  COCKROACH_API_KEY \
  TF_VAR_cockroach_owner_password \
  TF_VAR_cockroach_push_password \
  TF_VAR_cockroach_read_password; do
  value="$(fnox get "$name")"
  if [[ -z "$value" ]]; then
    echo "fnox returned an empty value for $name" >&2
    exit 1
  fi
  printf -v "$name" '%s' "$value"
  export "$name"
done

exec terraform "$@"
