```sh
% SQL(BigQuery)

# show tables [ex:dataset=logs, xx='appengine_googleapis_com_request_log_%']
SELECT * FROM <dataset>.INFORMATION_SCHEMA.TABLES where table_name like '<xx>_%';

# show tables columns [ex:dataset=logs, xx='appengine_googleapis_com_request_log_%']
SELECT column_name, ordinal_position, is_nullable,data_type FROM <dataset>.INFORMATION_SCHEMA.COLUMNS where table_name like '<xx>_%' order by ordinal_position;

# show column path [ex:dataset=logs, xx='appengine_googleapis_com_request_log_%']
SELECT table_name, column_name, field_path, data_type FROM <dataset>.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS;
```

$ xxx: echo xxx
;$
