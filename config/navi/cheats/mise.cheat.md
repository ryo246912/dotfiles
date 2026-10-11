```sh
% mise

# install package[npx: npm:prettier,pipx: pipx:httpie]
mise use -g <package>:<tool>

# install a bootstrap package without saving it to config
mise bootstrap packages apply <manager>:<system_package>

# add a bootstrap package to config and install it
mise bootstrap packages use <manager>:<system_package>

# display bootstrap package status
mise bootstrap packages status

# list installable list
mise use

# list installable package list
mise ls-remote <package> | less -iRMW --use-color

# display tool info
mise tool <package>

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
$ manager: echo -e "brew\nbrew-cask\napt\ndnf\npacman"
$ _--current: echo -e "\n --current"
;$
