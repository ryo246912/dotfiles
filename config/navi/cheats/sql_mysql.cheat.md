```sh
% SQL(MySQL)

# show databases
SHOW DATABASES;

# show tables
SHOW FULL TABLES;

# show tables from database
SHOW TABLES FROM <database>;

# show tables(filter)
SHOW TABLES LIKE '%<word>%';

# show columns and constraint
SHOW CREATE TABLE <table>;

# show columns
SHOW COLUMNS FROM <table> LIKE '%<word>%';

# show privilege=authority
SHOW GRANTS;

# show variables
SHOW VARIABLES LIKE '%<word>%';

# show variables2 [ex:SELECT @@time_zone , @@system_time_zone; SELECT @@GLOBAL.system_time_zone;]
SELECT @@<var>;

# set variables [ex:SET @var=0;,SET @num:=@num;,SET @@time_zone='+00:00';]
SET @<var>=<value>;

# grant privilege=add authority[authority:ALL,SELECT,INSERT,UPDATE][ex:GRANT SELECT ON <database>.<table> TO 'user1'@'localhost' IDENTIFIED BY 'pass']
GRANT ALL ON *.* TO '<user>'@'<host>';

# show columns
DESC <table>;

# select user
SELECT user, host FROM mysql.user;
```

;$
