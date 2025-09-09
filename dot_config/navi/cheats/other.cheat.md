```sh
% shortcut

# my shortcut list
cat ~/.local/share/chezmoi/not_config/shortcut/list.csv | column -t -s, | fzf --no-sort
```

```sh
;--------------------------------------------------------------
; other
;--------------------------------------------------------------
% other
# claude : mcp add
claude mcp add <name> -s <scope> -- <command>

# cspell : lint [-c:config file][-e:exclude file]
cspell --no-progress --gitignore . | less -iRMW --use-color

# cspell : lint base-branch...HEAD [--root:root directory, defaults=current directory]
cspell --no-progress --root ~ $(git diff --name-only --line-prefix=$(git rev-parse --show-toplevel)/ $(git merge-base origin/<merge-base> HEAD)...HEAD)

# cspell : search(show) dictionary [The word is found in a dictionary if * appears ex:sql *php]
cspell trace "<word>"

# deepl : transrate [-s: stdin]
deepl -s --to '<language>' <<< "<input>"

# ffmpeg : convert to mp4 file [-c:v video codec,-c:a audio codec]
ffmpeg -i <input_file> -c:v libx264 -c:a aac <input_file>.mp4

# ffmpeg : convert from mp4 file to gif file
ffmpeg -i <input_file> -vf "fps=10" <input_file>.gif

# inkscape : convert from svg file to png file
inkscape --export-filename="<output_file>.png" --export-width=<width> --export-height=<width> <input_file>

# Rust: install latest stable version
rustup install stable

# Rust: update
rustup update



# vim : move n rows
:<n>

# vim : reload current buffer(file) [e=edit]
:e

# vim : command history [q: → ctrl + c]
q:

# vim : command history search
q/

# vim : change paste mode
:set paste!

# vim : display leader key
:echo mapleader

# vscode : display installed extensions
code --list-extensions | xargs -L 1 echo code --install-extension > dot_config/vscode/executable_extensions.sh

# weather [version: v1=default output,v2=rich output] [location_or_help: ex)Tokyo]
curl -s "<version>wttr.in/<location_or_help>"

# zinit : report plugin
zi report

# zinit : report plugin loading time
zi times

# zinit : update plugin [ex:zinit update sharkdp/bat]
zi update <plugin>

# zinit : edit plugin [ex:zinit edit sharkdp/bat]
zi edit <plugin>

# zinit : delete plugin [ex:zinit delete sharkdp/bat]
zi delete <plugin>
```
; claude
$ scope: echo -e "user\nproject\nlocal"

; cspell
$ merge-base: gh pr list --search "$(git rev-parse --short HEAD)" --limit 1 --json baseRefName --jq '.[] | .baseRefName' && \
  echo master

$ language: echo -e "ja\nen"
$ input: echo -e '$(gopaste)\n'
$ version: echo -e "\nv2."
$ location_or_help: echo -e "\n:help"
