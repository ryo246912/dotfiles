```sh
% node

# nodenv display current version & installed versions
nodenv versions

# nodenv installable versions
nodenv install --list | less -iRMW --use-color

# nodenv install version
nodenv install <version>
```

```sh
% npm&pnpm

# display bin directory [ex: $(npm root)/.bin/cspell]
$(npm root)/.bin/<command>

# open package files [ex:npm edit axios]
npm edit <package>

# open package homepage [ex:npm home axios]
npm home <package>

# open package repo [ex:npm repo axios]
npm repo <package>

# open package issue page [ex:npm bugs axios]
npm bugs <package>

# prune unnecessary package
npm prune

# npx for pnpm
pnpm dlx <package>
```

```sh
% npx

# eslint : show config
npx eslint --print-config .eslintrc.js

# tsc : show config
npx tsc --showConfig

# sort package-json
npx sort-package-json
```

$ xxx: echo xxx
;$
