#!/usr/bin/env bash
set -euo pipefail

: "${AGENTSVIEW_OWNER_PROXY_PG_URL:?Set the Fly owner URL pointing at the local flyctl proxy}"
: "${AGENTSVIEW_COCKROACH_OWNER_PG_URL:?Set the CockroachDB owner URL}"
: "${AGENTSVIEW_MIGRATION_PROJECTS:?Set one small project for the target schema bootstrap}"

if [[ "${AGENTSVIEW_MIGRATION_WRITES_PAUSED:-}" != "yes" ]]; then
  cat >&2 <<'EOF'
Refusing to copy while writes might still be running.
Stop every AgentsView pg push/watch process, then set:
  AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes
Atuin does not need to be stopped because it does not write the agentsview schema.
EOF
  exit 1
fi

export AGENTSVIEW_PG_SCHEMA="${AGENTSVIEW_PG_SCHEMA:-agentsview}"

proxy_port="${AGENTSVIEW_PG_PROXY_PORT:-15432}"
proxy_app="${AGENTSVIEW_PG_APP:-psgl}"
backup_dir="${AGENTSVIEW_MIGRATION_BACKUP_DIR:-$HOME/backup}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump_file="$backup_dir/agentsview-fly-$timestamp.sql"
source_counts="$(mktemp)"
target_counts="$(mktemp)"
table_list="$(mktemp)"
proxy_log="$(mktemp)"

cleanup() {
  if [[ -n "${proxy_pid:-}" ]]; then
    kill "$proxy_pid" 2>/dev/null || true
    wait "$proxy_pid" 2>/dev/null || true
  fi
  rm -f "$source_counts" "$target_counts" "$table_list" "$proxy_log"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for command in agentsview flyctl nc pg_dump psql; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

if nc -z 127.0.0.1 "$proxy_port" >/dev/null 2>&1; then
  echo "127.0.0.1:$proxy_port is already in use" >&2
  exit 1
fi

mkdir -p "$backup_dir"
umask 077

flyctl proxy "${proxy_port}:5432" -a "$proxy_app" >"$proxy_log" 2>&1 &
proxy_pid=$!

for _ in $(seq 1 40); do
  nc -z 127.0.0.1 "$proxy_port" >/dev/null 2>&1 && break
  if ! kill -0 "$proxy_pid" 2>/dev/null; then
    cat "$proxy_log" >&2
    exit 1
  fi
  sleep 0.25
done
nc -z 127.0.0.1 "$proxy_port" >/dev/null 2>&1 || {
  cat "$proxy_log" >&2
  echo "Timed out waiting for flyctl proxy" >&2
  exit 1
}

echo "[1/6] Bootstrapping the CockroachDB schema with AgentsView..."
AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_OWNER_PG_URL" \
  agentsview pg push --no-vectors --projects "$AGENTSVIEW_MIGRATION_PROJECTS"

echo "[2/6] Creating a private, data-only Fly backup: $dump_file"
PGDATABASE="$AGENTSVIEW_OWNER_PROXY_PG_URL" pg_dump \
  --schema=agentsview \
  --data-only \
  --column-inserts \
  --on-conflict-do-nothing \
  --no-owner \
  --no-privileges \
  --file="$dump_file"
chmod 600 "$dump_file"

echo "[3/6] Recording exact source row counts..."
PGDATABASE="$AGENTSVIEW_OWNER_PROXY_PG_URL" psql -X -v ON_ERROR_STOP=1 -At <<'SQL' >"$table_list"
SELECT format('%I.%I', table_schema, table_name)
FROM information_schema.tables
WHERE table_schema = 'agentsview' AND table_type = 'BASE TABLE'
ORDER BY table_name;
SQL
while IFS= read -r table; do
  count=$(PGDATABASE="$AGENTSVIEW_OWNER_PROXY_PG_URL" psql -X -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM $table")
  printf '%s\t%s\n' "$table" "$count" >>"$source_counts"
done <"$table_list"

echo "[4/6] Restoring rows into CockroachDB (idempotent inserts)..."
PGDATABASE="$AGENTSVIEW_COCKROACH_OWNER_PG_URL" psql -X -v ON_ERROR_STOP=1 -f "$dump_file"

echo "[5/6] Recording exact target row counts..."
while IFS= read -r table; do
  count=$(PGDATABASE="$AGENTSVIEW_COCKROACH_OWNER_PG_URL" psql -X -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM $table")
  printf '%s\t%s\n' "$table" "$count" >>"$target_counts"
done <"$table_list"

echo "[6/6] Comparing exact table counts..."
if ! diff -u "$source_counts" "$target_counts"; then
  echo "Count mismatch. Keep Fly as the source of truth and investigate before cutover." >&2
  echo "Backup retained at: $dump_file" >&2
  exit 1
fi

echo "Migration copy completed. Backup retained at: $dump_file"
echo "Do not delete the Fly schema yet. Run the documented status/viewer/smoke tests first."
