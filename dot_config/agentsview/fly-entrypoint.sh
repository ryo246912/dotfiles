#!/bin/sh
set -eu

: "${AGENTSVIEW_PG_URL:?AGENTSVIEW_PG_URL must be set with fly secrets set}"
: "${AGENTSVIEW_AUTH_TOKEN:?AGENTSVIEW_AUTH_TOKEN must be set with fly secrets set}"

data_dir=${AGENTSVIEW_DATA_DIR:-/data}
config_file="${data_dir}/config.toml"
pg_schema=${AGENTSVIEW_PG_SCHEMA:-agentsview}
port=${PORT:-8080}

if [ -n "${AGENTSVIEW_PUBLIC_URL:-}" ]; then
    public_url=$AGENTSVIEW_PUBLIC_URL
elif [ -n "${FLY_APP_NAME:-}" ]; then
    public_url="https://${FLY_APP_NAME}.fly.dev"
else
    public_url="http://127.0.0.1:${port}"
fi

toml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

mkdir -p "$data_dir"
umask 077

tmp_config=$(mktemp "${config_file}.XXXXXX")
cleanup() {
    if [ -n "${tmp_config:-}" ] && [ -f "$tmp_config" ]; then
        rm -f "$tmp_config"
    fi
}
trap cleanup EXIT HUP INT TERM

pg_url_escaped=$(toml_escape "$AGENTSVIEW_PG_URL")
auth_token_escaped=$(toml_escape "$AGENTSVIEW_AUTH_TOKEN")
public_url_escaped=$(toml_escape "$public_url")
pg_schema_escaped=$(toml_escape "$pg_schema")

cat >"$tmp_config" <<EOF
require_auth = true
auth_token = "${auth_token_escaped}"
public_url = "${public_url_escaped}"
public_origins = ["${public_url_escaped}"]
disable_update_check = true

[pg]
url = "${pg_url_escaped}"
schema = "${pg_schema_escaped}"
allow_insecure = false
EOF

chmod 0600 "$tmp_config"
mv "$tmp_config" "$config_file"
tmp_config=

exec agentsview pg serve \
    --host 0.0.0.0 \
    --port "$port" \
    --public-url "$public_url" \
    --public-origin "$public_url" \
    --no-browser \
    --no-update-check
