```sh
% sql

# show databases
SELECT schema_name FROM information_schema.schemata;

# show tables
SELECT table_name FROM information_schema.tables WHERE table_schema = '<database>';

# show tables(filter)
SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%<word>%';

# show columns and constraint
SHOW CREATE TABLE <table>;

# show columns
SELECT column_name FROM information_schema.columns WHERE table_name = '<table>' AND column_name LIKE '%<word>%';

# show increment
SELECT
	TABLE_NAME,
	AUTO_INCREMENT
FROM
	INFORMATION_SCHEMA.TABLES
WHERE
  TABLE_NAME LIKE '%<table>%'
ORDER BY TABLE_NAME;

# alter auto increment
ALTER TABLE <table> AUTO_INCREMENT = <number>;

# insert record [ex:INSERT INTO "Tbl" (col1,col2) VALUES ('str',0);]
INSERT INTO <table> (<column>) VALUES (<value>);

# delete record [ex:DELETE FROM EMP WHERE id = 10;]
DELETE FROM <table> WHERE <column> = <value>;

# concat
SELECT CONCAT("test","\n","");

# convert timezone 1 [ex.SELECT CONVERT_TZ('2024-12-12 12:00:00', 'UTC', 'Asia/Tokyo') AS JST_TIME; ]
SELECT CONVERT_TZ('<time>', 'UTC', 'Asia/Tokyo');

# convert timezone 2 [ex.SELECT DATE_ADD('2024-12-12 12:00:00', INTERVAL 9 HOUR) AS JST_TIME; ]
SELECT DATE_ADD('<time>', INTERVAL 9 HOUR);

# convert timezone 3 [ex.SELECT '2024-12-12 12:00:00' + INTERVAL 9 HOUR AS JST_TIME; ]
SELECT '<time>' + INTERVAL 9 HOUR;

# convert timezone 4 [ex.SELECT '2024-12-12 12:00:00' + INTERVAL 9 HOUR AS JST_TIME; ]
SELECT CONVERT_TZ(<time>, '+00:00', '+09:00');

# add day 1 [ex. SELECT DATE_ADD('2023-12-13', INTERVAL 1 DAY) AS added_date;]
SELECT DATE_ADD('<time>', INTERVAL 1 DAY);

# add day 2 [ex. SELECT ADDDATE('2023-12-13', INTERVAL 1 DAY) AS added_date;]
SELECT ADDDATE('<time>', INTERVAL 1 DAY);

# add day 3 [ex. SELECT DATE_FORMAT(DATE_ADD('2023-12-13', INTERVAL 1 DAY), '%Y-%m-%d') AS added_date;]
SELECT DATE_FORMAT(DATE_ADD('<time>', INTERVAL 1 DAY), '%Y-%m-%d');

# subtract day 1 [ex. SELECT DATE_SUB('2023-12-13 09:00:00', INTERVAL 1 DAY) AS subtracted_date;]
SELECT DATE_SUB('<time>', INTERVAL 1 DAY);

# subtract day 2 [ex. SELECT SUBDATE('2023-12-13', INTERVAL 1 DAY) AS subtracted_date;]
SELECT SUBDATE('<time>', INTERVAL 1 DAY);

# subtract day 3 [ex. SELECT DATE_ADD('2023-12-13', INTERVAL -1 DAY) AS subtracted_date;]
SELECT DATE_ADD('<time>', INTERVAL -1 DAY);

# calculate date difference [ex. SELECT DATEDIFF('2023-12-13', '2023-12-10') AS days_difference;]
SELECT DATEDIFF('<date1>', '<date2>');

# current date
SELECT CURRENT_DATE;

# date format
SELECT DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01');
```

$ xxx: echo xxx
;$
