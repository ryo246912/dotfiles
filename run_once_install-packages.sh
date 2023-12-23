#!/bin/bash
{{ if eq .chezmoi.os "darwin" }}
### hard link ###

# commitizen #
ln -f ~/.config/commitizen/.czrc ~/.czrc
ln -f ~/.config/commitizen/.commitlintrc.js ~/.commitlintrc.js

# navi #
[ -e "~/.config/private/navi/mycheat_private.cheat.md" ] && ln -f ~/.config/private/navi/mycheat_private.cheat.md ~/.config/navi/cheats
ln -f ~/.private/.zprofile.secret ~
ln -f ~/.private/navi/mycheat_private.cheat ~/.navi/cheats
ln -f vscode/snippet/global.code-snippets ~/.vscode/

read -r -d '' PACKAGES <<EOF
act
colordiff
ncdu
t-rec
yqrashawn/goku/goku

coreutils
findutils
gnu-sed
grep
EOF

for package in $(echo $PACKAGES); do
  brew install $package
done

read -r -d '' CASKPACKAGES <<EOF
alacritty
arc
karabiner-elements
keyboardcleantool
rio
shortcat
visual-studio-code
EOF

for package in $(echo $CASKPACKAGES); do
  brew install --cask $package
done
{{ end }}
