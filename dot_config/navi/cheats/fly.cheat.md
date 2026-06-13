```sh
% fly

# auth login
flyctl auth signup

# display apps list
flyctl apps list

# deploy app
flyctl deploy --app ryo-shellhistory -c dot_config/atuin/fly.toml

# deploy AgentsView PostgreSQL viewer
flyctl deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml

# create AgentsView data volume
flyctl volumes create agentsview_data -a ryo-agentsview -r nrt --size 1

# set AgentsView secrets
flyctl secrets set -a ryo-agentsview AGENTSVIEW_PG_URL="<postgres_url_with_sslmode_require>" AGENTSVIEW_AUTH_TOKEN="$(openssl rand -base64 32)"

# set AgentsView PostgreSQL URL only
flyctl secrets set -a ryo-agentsview AGENTSVIEW_PG_URL="<postgres_url_with_sslmode_require>"

# set AgentsView bearer token only
flyctl secrets set -a ryo-agentsview AGENTSVIEW_AUTH_TOKEN="$(openssl rand -base64 32)"

# verify AgentsView API requires bearer auth
curl -i https://ryo-agentsview.fly.dev/api/v1/sessions

# verify AgentsView API with bearer auth
curl -i -H "Authorization: Bearer <token>" https://ryo-agentsview.fly.dev/api/v1/sessions

# verify AgentsView security headers
curl -I https://ryo-agentsview.fly.dev

# connect postgres for AgentsView schema setup
flyctl postgres connect -a "<psgl_app>"

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
