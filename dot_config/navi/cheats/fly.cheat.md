```sh
% fly

# auth login
flyctl auth signup

# display apps list
flyctl apps list

# deploy app
flyctl deploy --app ryo-shellhistory -c dot_config/atuin/fly.toml

# status
flyctl status -a "<app>"

# ssh
flyctl ssh console -a "<app>"

# open dashboard
flyctl dashboard -a "<app>"

# display log
flyctl logs -a "<app>"

# connect postgres
flyctl postgres connect -a "<psgl_app>"

# open docs
flyctl docs
```

$ app: flyctl apps list \
  --- --headers 1 --map "awk '{print $1}'"
$ psgl_app: echo -e "psgl\n"
;$
