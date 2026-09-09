```sh
;--------------------------------------------------------------
; cloudflare
;--------------------------------------------------------------
% cloudflare

# pages : display project list
wrangler pages project list

# pages : display deploy list
wrangler pages deployment list --project-name <project-name>

# pages : display deploy detail [--environment:"production/preview"]
wrangler pages deployment tail --environment <environment>
```

$ project-name: echo -e "blog\n"
$ environment: echo -e "production\npreview"
;$

```sh
;--------------------------------------------------------------
; blog
;--------------------------------------------------------------
% blog

# git : create preview branch
git branch -f <branch>

# git : push preview branch(deploy)
git push -f origin <branch>
```

$ branch: echo -e "preview\n"
;$
