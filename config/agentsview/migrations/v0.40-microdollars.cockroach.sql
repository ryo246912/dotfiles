-- AgentsView 0.39以前のschemaを、0.40以降のmoney列（microdollarのBIGINT）へ移す。
--
-- AgentsView自身もpg pushの先頭で同じmigrationを行うが（internal/postgres/schema.go
-- のmigrateMoneyColumnsPG）、CockroachDBでは次の2点で必ず失敗する。
--   - lockに使う hashtext() がCockroachDBに無い（SQLSTATE 42883）
--   - データの書き換えを伴う ALTER COLUMN TYPE は、CockroachDBではtransaction内で
--     実行できない（SQLSTATE 0A000）。AgentsViewは全体を1 transactionで行う
-- そこで同じDDLを、transactionで包まずに1文ずつ流す。DDLと換算式は上流の
-- migrateMoneyColumnsPGと同じである。各列がrenameされていれば、AgentsViewは
-- このmigrationを飛ばす。
--
-- 上流が行うcursor_usage_eventsのdedup_keyの再計算（Go側で行う処理）は、ここでは
-- 再現しない。実行前に `SELECT count(*) FROM agentsview.cursor_usage_events` が0で
-- あることを確認する。
--
-- 実行（owner role。1度だけ。psqlの -1／--single-transaction は付けない）:
--   fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X \
--     -v ON_ERROR_STOP=1 -f config/agentsview/migrations/v0.40-microdollars.cockroach.sql'
-- 途中で落ちた場合は、成功した文はすでに反映されている。その文を消してから再実行する。
SET search_path = agentsview;

ALTER TABLE usage_events ALTER COLUMN cost_usd TYPE BIGINT
  USING CASE WHEN cost_usd IS NULL THEN NULL ELSE ROUND((cost_usd::NUMERIC) * 1000000)::BIGINT END;
ALTER TABLE usage_events RENAME COLUMN cost_usd TO cost_microdollars;

ALTER TABLE cursor_usage_events ALTER COLUMN charged_cents TYPE BIGINT
  USING ROUND((charged_cents::NUMERIC) * 10000)::BIGINT;
ALTER TABLE cursor_usage_events RENAME COLUMN charged_cents TO charged_microdollars;
ALTER TABLE cursor_usage_events ALTER COLUMN cursor_token_fee TYPE BIGINT
  USING ROUND((cursor_token_fee::NUMERIC) * 10000)::BIGINT;
ALTER TABLE cursor_usage_events RENAME COLUMN cursor_token_fee TO cursor_token_fee_microdollars;

ALTER TABLE model_pricing ALTER COLUMN input_per_mtok TYPE BIGINT
  USING ROUND((input_per_mtok::NUMERIC) * 1000000)::BIGINT;
ALTER TABLE model_pricing RENAME COLUMN input_per_mtok TO input_microdollars_per_mtok;
ALTER TABLE model_pricing ALTER COLUMN output_per_mtok TYPE BIGINT
  USING ROUND((output_per_mtok::NUMERIC) * 1000000)::BIGINT;
ALTER TABLE model_pricing RENAME COLUMN output_per_mtok TO output_microdollars_per_mtok;
ALTER TABLE model_pricing ALTER COLUMN cache_creation_per_mtok TYPE BIGINT
  USING ROUND((cache_creation_per_mtok::NUMERIC) * 1000000)::BIGINT;
ALTER TABLE model_pricing RENAME COLUMN cache_creation_per_mtok TO cache_creation_microdollars_per_mtok;
ALTER TABLE model_pricing ALTER COLUMN cache_read_per_mtok TYPE BIGINT
  USING ROUND((cache_read_per_mtok::NUMERIC) * 1000000)::BIGINT;
ALTER TABLE model_pricing RENAME COLUMN cache_read_per_mtok TO cache_read_microdollars_per_mtok;
