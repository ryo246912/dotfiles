```sh
% brew

# list [--cask,--formula][-1:one column]
brew list --versions<_--filter> | less -iRMW --use-color

# install app [-n:dry-run][app:formula,user/repo/formula][ex:brew install -n fzf]
brew install<_--dry-run><_--cask> <app_name>

# upgrade app
brew upgrade<_--cask> <app_name>

# uninstall unnecessary dependence
brew autoremove

# app dependence [--tree:][--installed:list dependencies currently installed][ex:brew deps --tree ruby]
brew deps --installed --tree <app_name>

# display install formula [ex:bat -l rb $(brew edit --print-path ruby)]
bat -l rb $(brew edit --print-path <app_name>)

# open app homegage [ex:brew home colordiff]
brew home <app_name>

# tool
brew info --installed --json | jq 'map(select(.installed[].installed_on_request == true)) | map({key: .full_name, value: .installed[0].version}) | from_entries' > ~/.local/share/chezmoi/dot_config/brew/brew.json

# cask
brew info --cask --installed --json=v2 | jq '.casks | map({key: .full_token, value: .version}) | from_entries' > ~/.local/share/chezmoi/dot_config/brew/brew_cask.json
```
$ app_name: brew list -1 | grep -v "==>"
$ _--filter: echo -e "\n --formula\n --cask"
$ _--dry-run: echo -e "\n --dry-run"
$ _--cask: echo -e "\n --cask"
;$

```sh
% blueutil

# turn on-off bluetooth
blueutil --power <on_off>

# connect device
blueutil --power 1 && blueutil --connect <device>

# disconnect device
blueutil --disconnect <device> && blueutil --power 0

# connect/disconnect device
blueutil --paired --format json-pretty
```
$ on_off: echo -e "1\n0"
$ device: blueutil --paired --format json-pretty \
  | jq -r '["address","name","connected"] , (.[] | [.address , .name , (if .connected then "◯" else "☓" end)]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 1

```sh
% mac
# jot(BSD) : [-r:random]
jot -r 1

# display mac commnad [-r:recursive]
zgrep -lr -e 'Mac OS X' -e 'macOS' /usr/share/man/*/* | less -iRMW --use-color

# defaults : display system defaults
defaults read | less -iRMW --use-color

# defaults : output system defaults and diff
defaults read > before ; echo "入力待ちです" ; read ; defaults read > after && delta before after

# defaults : read shortcut key
defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys | awk '/[^0-9]<No> = /,/};/'

# lsappinfo : display running application
lsappinfo list | less -iRMW --use-color

# networksetup : display network devices
networksetup -listallhardwareports

# networksetup : display connected network list
networksetup -listpreferredwirelessnetworks en0

# networksetup : toggle wifi power on/off
networksetup -setairportpower en0 on

# sw_vers : display macOS version
sw_vers

# system_profiler : display system profile
system_profiler <datatype>

# perf : delete cache memory
sudo purge

# perf : delete cache memory(watch)
watch -n 900 -edt 'sudo purge'

# perf : delete system cache(/System/Library/Caches) local cache(/Library/Caches/) user cache(~/Library/Caches)
sudo rm -rf /System/Library/Caches/* /Library/Caches/* ~/Library/Caches/*

# perf : swap off(=unload) , swap on(=load)
sudo launchctl <load_unload> /System/Library/LaunchDaemons/com.apple.dynamic_pager.plist

# perf : delete escaping memory data for sleep mode
sudo rm -r /private/var/vm/sleepimage

# open app(macOS)
open-cli <url_or_file> -- <app>

# t-rec : record to gif [-q:quiet][-w:rec window]
t-rec -q -w <window> -o ~/private/gif/$(date "+%y%m%d-%H%M%S")_<name>
```
$ datatype : system_profiler -listDataTypes \
  --- --multi --expand
$ load_unload: echo -e "unload\nload"
$ app : system_profiler "SPApplicationsDataType" -json \
  | jq -r '["app","path"] ,(.SPApplicationsDataType[] | [._name , .path]) | @tsv' \
  | column -ts $'\t' \
  --- --headers 1 --column 2
$ window: t-rec --ls-win \
  | column -ts $'|' \
  --- --headers 1 --column 2
;$
