```sh
% fly

# auth login
flyctl auth signup

# display apps list
fly apps list

# status
fly status -a "<app>"

# ssh
fly ssh console -a "<app>"

# open dashboard
fly dashboard -a "<app>"

# display log
fly logs -a "<app>"

# connect postgres
fly postgres connect -a "<psgl_app>"

# open docs
fly docs
```

$ app: fly apps list \
  --- --headers 1 --column 1
$ psgl_app: echo -e "psgl\n"
;$
