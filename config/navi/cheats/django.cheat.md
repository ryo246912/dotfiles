```sh
% django

# show migration app [ex:python manage.py showmigrations issues]
python manage.py showmigrations <app_name>

# make migration
python manage.py makemigrations --name <name>

# migrate [ex:python manage.py migrate concierges 0031][zero:all reset,ex:python manage.py migrate concierges zero]
python manage.py migrate <app_name> <migration_name>

# check migration [ex:python manage.py sqlmigrate issues 0035]
python manage.py sqlmigrate <app_name> <migration_name>
```

$ xxx: echo xxx
;$
