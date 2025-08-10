```sh
% shortcut

# my shortcut list
cat ~/.local/share/chezmoi/not_config/shortcut/list.csv | column -t -s, | fzf --no-sort
```

```sh
;--------------------------------------------------------------
; claude
;--------------------------------------------------------------
% claude

# mcp add
claude mcp add <name> -s <scope> -- <command>
```

$ scope: echo -e "user\nproject\nlocal"
;$

```sh
;--------------------------------------------------------------
; cspell
;--------------------------------------------------------------
% cspell

# lint [-c:config file][-e:exclude file]
cspell --no-progress --gitignore . | less -iRMW --use-color

# lint base-branch...HEAD [--root:root directory, defaults=current directory]
cspell --no-progress --root ~ $(git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ $(git merge-base origin/<merge-base> HEAD)...HEAD)

# search(show) dictionary [The word is found in a dictionary if * appears ex:sql *php]
cspell trace "<word>"
```

$ merge-base: gh pr list --search "$(git rev-parse --short HEAD)" --limit 1 --json baseRefName --jq '.[] | .baseRefName' && \
  echo master
;$


```sh
;--------------------------------------------------------------
; Rust
;--------------------------------------------------------------
% Rust

# Rust install latest stable version
rustup install stable

# Rust update
rustup update

```

```sh
;--------------------------------------------------------------
; vim
;--------------------------------------------------------------
% vim:command
# move n rows
:<n>

# reload current buffer(file) [e=edit]
:e

# command history [q: → ctrl + c]
q:

# command history search
q/
# change paste mode
:set paste!

# display leader key
:echo mapleader
```

```sh
;--------------------------------------------------------------
; zinit
;--------------------------------------------------------------
% zinit
# report plugin
zi report

# report plugin loading time
zi times

# update plugin [ex:zinit update sharkdp/bat]
zi update <plugin>

# edit plugin [ex:zinit edit sharkdp/bat]
zi edit <plugin>

# delete plugin [ex:zinit delete sharkdp/bat]
zi delete <plugin>
```

```sh
;--------------------------------------------------------------
; other
;--------------------------------------------------------------
% other
# deepl : transrate [-s: stdin]
deepl -s --to '<language>' <<< "<input>"

# ffmpeg : convert to mp4 file [-c:v video codec,-c:a audio codec]
ffmpeg -i <input_file> -c:v libx264 -c:a aac <input_file>.mp4

# ffmpeg : convert from mp4 file to gif file
ffmpeg -i <input_file> -vf "fps=10" <input_file>.gif

# inkscape : convert from svg file to png file
inkscape --export-filename="<output_file>.png" --export-width=<width> --export-height=<width> <input_file>

# vscode : display installed extensions
code --list-extensions | xargs -L 1 echo code --install-extension > dot_config/vscode/executable_extensions.sh

# weather [version: v1=default output,v2=rich output] [location_or_help: ex)Tokyo]
curl -s "<version>wttr.in/<location_or_help>"
```

$ language: echo -e "ja\nen"
$ input: echo -e '$(gopaste)\n'
$ version: echo -e "\nv2."
$ location_or_help: echo -e "\n:help"
