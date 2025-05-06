```sh
% postgreSQL

# login [-U:user][-p:port,default 5432][-d:database]
psql -U <user> -p "<port>" -d "<database>"

# display(list) databases
psql -l

# bump
pg_dump -U <user> -d <db> > backup.sql

# restore
psql -U <user> -d <db> < backup.sql

# display(list) databases [+:with size, tablespace, and description]
\l+

# connect database
\c <database>

# display tables list
\dt

# display table column
\d+ <table>

# display connection info
\conninfo
```

$ xxx: echo xxx
;$
