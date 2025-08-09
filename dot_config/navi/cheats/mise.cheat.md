```sh
% mise

# install package[npx: npm:prettier,pipx: pipx:httpie]
mise use -g <package>:<tool>

# list installable list
mise use

# list installable package list
mise ls-remote <package> | less -iRMW --use-color

# set only current shell session[ex:mise shell node@20]
mise shell <tool_version>

# exec command [ex:mise exec -- node -v,mise exec node@20 python@3.11 --command "node -v && python -V"]
mise exec -- <command>

# set settings [ex:mise settings idiomatic_version_file=true]
mise settings <key>=<value>

# display config
mise config get

# display config list[ex:mise shell node@20]
mise config
```
$ package: echo -e "npm\npipx\naqua"
$ _--current: echo -e "\n --current"
;$
