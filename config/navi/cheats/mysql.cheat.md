```sh
% MySQL

# login [-h:host][-u:user][-D:database][-p:password ex)-prootpass]
mysql -h <host> -u <user> -D <database> -p<pass>

# show query log
mysql -u<user> -p<pass> -e "SET GLOBAL general_log='ON'; SET GLOBAL general_log_file='/tmp/general_log.txt';" && tail -f /tmp/general_log.txt
```

$ xxx: echo xxx
;$
