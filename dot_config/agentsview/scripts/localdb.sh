#!/usr/bin/env bash
set -euo pipefail

# local AgentsView databaseの操作をまとめたscript。container定義は compose.yaml、
# localをCockroachDBにしている理由は docs/agentsview.md にある。
#
# 使えるmode:
#   up                   local CockroachDBを起動し、databaseの存在を確認する
#   down                 local containerを止める（volumeは残す）
#   sql                  local CockroachDBへ対話SQL shellで接続する
#   status               engine versionとmachineごとのsession数を表示する
#   push [args]          このmachineのsessionをlocal CockroachDBへpushする
#   serve [args]         pushし続けながらlocal CockroachDBからAgentsViewを配信する
#   dump                 local CockroachDBをdata-only INSERTのdumpへ書き出す
#   restore [file]       dump（remote／local）の不足rowをlocal CockroachDBへmergeする
#   repair-sequences     sequenceを実dataのidまで前進させる（巻き戻さない）
#
# macOS既定のbash 3.2でも動く範囲で書く（空arrayやwait -nを使わない）。

mode="${1:?up／down／sql／status／push／serve／dump／restore などのmodeを指定してください}"
shift

# dumpにはsession本文が入るので、作るfileとdirectoryは所有者だけが読めるようにする。
umask 077

# 解決順は cloudrun.sh と同じ。repository rootから実行した場合はsource treeを、
# それ以外はchezmoi apply済みの ~/.config/agentsview を使う。
config_dir="${AGENTSVIEW_CONFIG_DIR:-dot_config/agentsview}"
if [ ! -f "${config_dir}/compose.yaml" ]; then
  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/agentsview"
fi
compose_file="${AGENTSVIEW_COMPOSE_FILE:-${config_dir}/compose.yaml}"
if [ ! -f "$compose_file" ]; then
  echo "compose.yaml が見つかりません: ${compose_file}" >&2
  exit 1
fi

# dumpをCockroachDBへ流せるINSERT列へ変換するfilter。chezmoi source treeでは
# executable_ prefixが付いたままなので、両方の名前を見る。
filter="${AGENTSVIEW_BATCH_INSERT_DUMP:-${config_dir}/batch-insert-dump}"
if [ ! -f "$filter" ]; then
  filter="${config_dir}/executable_batch-insert-dump"
fi
if [ ! -f "$filter" ]; then
  echo "batch-insert-dump が見つかりません: ${config_dir}" >&2
  exit 1
fi

schema="${AGENTSVIEW_PG_SCHEMA:-agentsview}"
database="${AGENTSVIEW_LOCAL_CRDB_DATABASE:-agentsview}"
db_user="${AGENTSVIEW_LOCAL_CRDB_USER:-root}"
host_port="${AGENTSVIEW_LOCAL_CRDB_PORT:-26257}"
backup_dir="${AGENTSVIEW_BACKUP_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/agentsview}"

# composeが読む値。どのmodeから来ても同じcontainerを指すようにexportする。
export AGENTSVIEW_LOCAL_CRDB_DATABASE="$database"
export AGENTSVIEW_LOCAL_CRDB_PORT="$host_port"
export AGENTSVIEW_LOCAL_CRDB_HTTP_PORT="${AGENTSVIEW_LOCAL_CRDB_HTTP_PORT:-18080}"

mkdir -p "$backup_dir"

# hostから見たURL（composeがpublishしたport）と、container netnsから見たURL
# （container内のport）は別物である。agentsview CLIはhost側、psql／pg_dumpは
# container側を使う。ここを混同すると、portを既定から変えたときだけ壊れる。
host_url="postgres://${db_user}@127.0.0.1:${host_port}/${database}?sslmode=disable"
container_url="postgres://${db_user}@127.0.0.1:26257/${database}?sslmode=disable"

# 後片付けは1つのEXIT trapへ集める。個々の処理でtrapを張り替えると、
# import中に張り直したtrapが外側の後片付けを消してしまう。
temp_counts_before=""
temp_counts_after=""

remove_temp() {
  [ -n "$1" ] || return 0
  rm -f "$1"
}

compose() {
  docker compose -f "$compose_file" "$@"
}

on_exit() {
  remove_temp "$temp_counts_before"
  remove_temp "$temp_counts_after"
}
trap on_exit EXIT

# psql／pg_dumpのimage pinはcompose.yamlのpgtools serviceにある（renovateが更新
# する）。値の解決だけを借りて、起動は docker run で行う。`config --images pgtools`
# は依存service（network_mode先のcockroach）のimageも並べて返し、順序も保証され
# ないため、service名で引けるJSONから読む。
pgtools_image="${AGENTSVIEW_PGTOOLS_IMAGE:-}"
if [ -z "$pgtools_image" ]; then
  pgtools_image="$(compose --profile tools config --format json |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["services"]["pgtools"]["image"])')"
fi
if [ -z "$pgtools_image" ]; then
  echo "pgtools imageを解決できません: ${compose_file}" >&2
  exit 1
fi

# CockroachDBのimageにclient toolが無いため、pgtools imageをcockroach containerの
# netnsで動かす。docker composeのrunは進捗をstdoutへ出しうるため、query結果を
# parseする用途では docker run を使う。
pgtools() {
  local cid
  cid="$(compose ps -q cockroach)"
  if [ -z "$cid" ]; then
    echo "local CockroachDBが起動していません。先に up を実行してください。" >&2
    return 1
  fi
  docker run --rm --interactive --network "container:${cid}" "$pgtools_image" "$@"
}

psql_local() {
  pgtools psql "$container_url" --set=ON_ERROR_STOP=1 "$@"
}

# 値をparseするquery用。header・整列・行数表示を外す。
query_local() {
  psql_local --no-align --tuples-only --quiet --field-separator='|' "$@"
}

require_agentsview() {
  command -v agentsview >/dev/null && return 0
  echo "agentsviewが見つかりません。mise install を実行してください" >&2
  exit 1
}

ensure_up() {
  compose up -d --wait cockroach
  # COCKROACH_DATABASEはvolumeが空の初回起動時だけ効く。既存volumeやdatabase名を
  # 変えた場合に備え、起動ごとに存在を確認する（あれば何もしない）。
  compose exec -T cockroach cockroach sql --insecure \
    --execute="CREATE DATABASE IF NOT EXISTS \"${database}\"" >/dev/null
}

schema_exists() {
  local count
  count="$(query_local --command="SELECT count(*) FROM information_schema.schemata
    WHERE schema_name = '${schema}'" | tr -d '[:space:]')"
  [ "$count" = "1" ]
}

require_schema() {
  schema_exists && return 0
  echo "local CockroachDBに ${schema} schemaがありません: ${compose_file}" >&2
  echo "このmachineのsessionを収集するか、dumpをrestoreしてから再実行してください:" >&2
  echo "  mise run agentsview:cockroach:local:push" >&2
  echo "  mise run agentsview:cockroach:remote-local:restore" >&2
  return 1
}

# restore／importは明示idのINSERTを流すので、そのあとsequenceが実dataより遅れる。
# 放置すると次のINSERTがduplicate keyで落ちる。GREATESTで包むことで、進んでいる
# sequenceを巻き戻さずに前進だけさせる。CockroachDBのSERIALはunique_rowid()が
# 既定でsequenceを持たないため、その場合は対象0件で何もしない。
repair_sequences() {
  local rows statements table column column_default sequence
  rows="$(query_local --command="SELECT table_name, column_name, column_default
    FROM information_schema.columns
    WHERE table_schema = '${schema}' AND column_default LIKE 'nextval(%'
    ORDER BY table_name, column_name")"
  if [ -z "$rows" ]; then
    return 0
  fi
  statements=""
  while IFS='|' read -r table column column_default; do
    [ -n "$table" ] || continue
    sequence="$(printf '%s' "$column_default" | sed -n "s/^nextval('\([^']*\)'.*/\1/p")"
    if [ -z "$sequence" ]; then
      echo "sequence名を読み取れません: ${table}.${column} = ${column_default}" >&2
      return 1
    fi
    statements="${statements}SELECT setval('${sequence}', GREATEST(
      (SELECT COALESCE(max(\"${column}\"), 0) FROM \"${schema}\".\"${table}\"),
      (SELECT last_value FROM ${sequence}), 1), true);
"
  done <<EOF
${rows}
EOF
  printf '%s' "$statements" | psql_local --quiet --output=/dev/null
}

# 取り込み結果は「どのtableが何行増えたか」で確認したい。table一覧をschemaから
# 引き、count(*)は1 queryへまとめる（PostgreSQLのquery_to_xmlはCockroachDBに無い）。
row_counts() {
  local tables union table
  tables="$(query_local --command="SELECT table_name FROM information_schema.tables
    WHERE table_schema = '${schema}' AND table_type = 'BASE TABLE' ORDER BY table_name")"
  [ -n "$tables" ] || return 0
  union=""
  while IFS= read -r table; do
    [ -n "$table" ] || continue
    [ -z "$union" ] || union="${union} UNION ALL "
    union="${union}SELECT '${table}' AS t, count(*) AS c FROM \"${schema}\".\"${table}\""
  done <<EOF
${tables}
EOF
  query_local --field-separator=' ' --command="SELECT t, c FROM (${union}) AS counts ORDER BY t"
}

push_local() {
  require_agentsview
  ensure_up
  # AGENTSVIEW_PG_URLがremote向けにexportされていてもlocalへ向け直す。
  # --no-vectorsはremote pushと同じ理由（CockroachDBにpgvectorが無い）で常に付ける。
  AGENTSVIEW_PG_SCHEMA="$schema" AGENTSVIEW_PG_URL="$host_url" \
    agentsview pg push --no-vectors "$@"
}

# dumpのINSERTをchunkごとのtransactionで流し、前後の行数差を報告する。
import_sql_file() {
  temp_counts_before="$(mktemp)"
  temp_counts_after="$(mktemp)"

  row_counts >"$temp_counts_before"

  # CockroachDBは1 transactionで書ける量に上限があるため、filterがBEGIN/COMMITで
  # chunkへ割る。途中で失敗するとそこまでのchunkはcommit済みで残るが、INSERTは
  # すべてON CONFLICT DO NOTHINGなので、原因を直して同じfileを再実行できる。
  "$filter" <"$1" | psql_local --quiet --output=/dev/null

  repair_sequences
  row_counts >"$temp_counts_after"

  awk -v schema="$schema" 'NR == FNR { before[$1] = $2; next }
    { printf "  %s.%s: %d -> %d (%+d rows)\n", schema, $1, before[$1], $2, $2 - before[$1] }' \
    "$temp_counts_before" "$temp_counts_after"
}

select_dump() {
  local path
  path="$1"
  if [ -z "$path" ]; then
    path="$({ find "$backup_dir" -maxdepth 1 -type f -name '*.sql' -print 2>/dev/null || true; } |
      sort -r |
      fzf --prompt='AgentsView dump> ' --height=40% --reverse || true)"
  fi
  if [ -z "$path" ]; then
    echo "No dump selected from: ${backup_dir}" >&2
    return 1
  fi
  if [ ! -f "$path" ]; then
    echo "Dump file not found: ${path}" >&2
    return 1
  fi
  printf '%s\n' "$path"
}

case "$mode" in
  up)
    ensure_up
    ;;
  down)
    # profileつきserviceは明示しないと止まらない。volumeは残す。
    compose --profile tools down "$@"
    ;;
  sql)
    ensure_up
    compose exec cockroach cockroach sql --insecure --database="$database" "$@"
    ;;
  status)
    ensure_up
    # remoteのengine versionと見比べられるようにlocal側も出す。
    psql_local --command="SELECT version() AS local_cockroachdb_version"
    require_schema
    psql_local --command="SELECT machine, count(*) AS sessions
      FROM \"${schema}\".sessions GROUP BY machine ORDER BY machine"
    ;;
  push)
    push_local "$@"
    ;;
  serve)
    push_local
    export AGENTSVIEW_PG_SCHEMA="$schema"
    export AGENTSVIEW_PG_URL="$host_url"

    agentsview pg push --watch --no-vectors &
    watch_pid=$!

    agentsview pg serve "$@" &
    serve_pid=$!

    cleanup_serve() {
      kill "$watch_pid" "$serve_pid" 2>/dev/null || true
      wait "$watch_pid" 2>/dev/null || true
      wait "$serve_pid" 2>/dev/null || true
      on_exit
    }

    trap cleanup_serve EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    # watcherが落ちたままserveを続けると、sessionの収集が黙って止まる。どちらかが
    # 終了したらもう一方も停止し、終了statusを引き継ぐ。macOS既定のbash 3.2には
    # `wait -n` がないためpollで監視する。
    while :; do
      if ! kill -0 "$watch_pid" 2>/dev/null; then
        watch_status=0
        wait "$watch_pid" || watch_status=$?
        echo "agentsview pg push --watch exited with status ${watch_status}; stopping serve" >&2
        kill "$serve_pid" 2>/dev/null || true
        wait "$serve_pid" 2>/dev/null || true
        exit "$watch_status"
      fi
      if ! kill -0 "$serve_pid" 2>/dev/null; then
        serve_status=0
        wait "$serve_pid" || serve_status=$?
        exit "$serve_status"
      fi
      sleep 1
    done
    ;;
  dump)
    push_local
    require_schema
    dump_path="${backup_dir}/agentsview-local-$(date +%Y%m%d-%H%M%S)-$$.sql"
    # schema DDLは持ち出さない。CockroachDBのDDL／権限／sequenceをそのまま別の
    # databaseへ流せる保証はなく、schemaは常に現在のAgentsViewが作るためである。
    if ! pgtools pg_dump --dbname="$container_url" --schema="$schema" \
      --data-only --column-inserts --on-conflict-do-nothing \
      --no-owner --no-privileges >"$dump_path"; then
      rm -f "$dump_path"
      exit 1
    fi
    # 壊れたdumpを残さないよう、statementとして読み切れることを確認する。
    if ! "$filter" <"$dump_path" >/dev/null; then
      rm -f "$dump_path"
      exit 1
    fi
    echo "Local CockroachDB AgentsView backup: ${dump_path}"
    ;;
  restore)
    dump_path="$(select_dump "${1:-${AGENTSVIEW_RESTORE_DUMP:-}}")"
    # 取り込む前にschemaを現在のAgentsView versionへ揃え、このmachineですでに
    # 収集したsessionも保持する。
    push_local
    import_sql_file "$dump_path"
    echo "Merged missing rows from AgentsView dump: ${dump_path}"
    ;;
  repair-sequences)
    ensure_up
    require_schema
    repair_sequences
    ;;
  *)
    echo "不明なmode: ${mode}" >&2
    exit 1
    ;;
esac
