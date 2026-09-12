-- schemaのdataを INSERT ... ON CONFLICT DO NOTHING の列へ書き出す。
--
-- pg_dumpを使わない理由: pg_dumpはCockroachDBをサポートしない
-- （cockroachdb/cockroach#20296）。--schema を渡すと
--   WHERE n.nspname OPERATOR(pg_catalog.~) '...' COLLATE pg_catalog.default
-- というqueryを送るが、CockroachDBは修飾付きのcollation名を解釈できない。
-- この COLLATE は pg_dump 12以降が server_version >= 12 のときに必ず付けるため、
-- optionでは避けられない（PostgreSQLの src/fe_utils/string_utils.c）。
--
-- そこで、行を組み立てるのはserverに任せる。列名を明示するので、AgentsViewが
-- 列を増やしても古いdumpが壊れない。
--
-- 呼び出し方（psqlの:'schema'はclient側で置換される）:
--   psql --set=schema=agentsview --tuples-only --no-align --quiet --file=- < このfile
--
-- 単一のtransactionで読むので、tableをまたいで一貫したsnapshotになる。
BEGIN;

-- 各tableについて「INSERT文を1行ずつ返すSELECT」を組み立て、\gexecで実行する。
-- 列一覧と値一覧は同じ ORDER BY ordinal_position で畳むので、必ず対応が取れる。
-- 値は col::text をquote_literalした文字列literalにする。挿入先の列型へ
-- coerceされるので、pg_dumpの--column-insertsと同じ往復になる。NULLは
-- quote_literalがNULLを返すため、COALESCEでSQLのNULLへ落とす。
--
-- tableの順はforeign keyに従う（参照される側を先に出す）。取り込みは
-- ON CONFLICT DO NOTHING のINSERTなので重複には強いが、参照先の行が無い状態の
-- INSERTはforeign key違反で落ちるため、順序だけは合わせる必要がある。
-- 辺は information_schema ではなく pg_catalog から取る。PostgreSQLの
-- information_schema.table_constraints は「SELECT以外の権限を持つtable」しか
-- 返さないので、read-only roleでdumpすると辺が1つも見えない。
WITH RECURSIVE edge AS (
  -- information_schemaの列はsql_identifier domainなので、textへ揃える。
  SELECT DISTINCT child.relname::text AS child, parent.relname::text AS parent
  FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class child ON child.oid = con.conrelid
    JOIN pg_catalog.pg_class parent ON parent.oid = con.confrelid
    JOIN pg_catalog.pg_namespace cns ON cns.oid = child.relnamespace
    JOIN pg_catalog.pg_namespace pns ON pns.oid = parent.relnamespace
  WHERE con.contype = 'f'
    AND cns.nspname = :'schema'
    AND pns.nspname = :'schema'
    -- 自己参照は行の順序の問題で、tableの順序では解けない。
    AND child.relname <> parent.relname
),
-- 参照先を持たないtableを深さ0とし、参照する側を1つ深くする。最長の経路を採るので
-- 親は必ず子より浅くなる。循環しているschemaでも止まるよう深さに上限を置く
-- （循環はどの順序でも解けないため、そこは名前順に落ちる）。
depth AS (
  SELECT t.table_name::text AS table_name, 0 AS depth
  FROM information_schema.tables t
  WHERE t.table_schema = :'schema' AND t.table_type = 'BASE TABLE'
  UNION ALL
  SELECT e.child, d.depth + 1
  FROM depth d
    JOIN edge e ON e.parent = d.table_name
  WHERE d.depth < 10
),
tbl AS (
  SELECT c.table_schema,
    c.table_name,
    string_agg(quote_ident(c.column_name), ', ' ORDER BY c.ordinal_position) AS cols,
    string_agg(
      'COALESCE(quote_literal(' || quote_ident(c.column_name) || '::text), ''NULL'')',
      ' || '', '' || ' ORDER BY c.ordinal_position
    ) AS vals
  FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
  WHERE c.table_schema = :'schema'
    AND t.table_type = 'BASE TABLE'
  GROUP BY c.table_schema, c.table_name
)
SELECT 'SELECT '
    || quote_literal(
         'INSERT INTO ' || quote_ident(tbl.table_schema) || '.' || quote_ident(tbl.table_name)
         || ' (' || tbl.cols || ') VALUES ('
       )
    || ' || ' || tbl.vals
    || ' || ' || quote_literal(') ON CONFLICT DO NOTHING;')
    || ' FROM ' || quote_ident(tbl.table_schema) || '.' || quote_ident(tbl.table_name)
FROM tbl
  JOIN (SELECT table_name, max(depth) AS depth FROM depth GROUP BY table_name) o
    ON o.table_name = tbl.table_name::text
ORDER BY o.depth, tbl.table_name
\gexec

-- 最後に完了markerを置く。information_schemaは権限でfilterされるので、schema名を
-- 間違えた場合や権限が足りない場合も、errorではなく「行が無い」という形で出る。
-- markerが無ければ途中で切れたかgeneratorが走っていない、tables=0ならschemaを
-- 読めていない、と batch-insert-dump が判定する。SQL commentなので取り込み時は
-- 読み飛ばされる。
SELECT '-- agentsview-dump-complete tables=' || count(*)
FROM information_schema.tables
WHERE table_schema = :'schema' AND table_type = 'BASE TABLE';

COMMIT;
