```sh
% tmux
# keys
tmux list-keys | less -iRMW --use-color

# list-panes
tmux list-panes -s -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty} [history #{history_size}/#{history_limit}, #{history_bytes} bytes]" | column -t

# move pane
tmux choose-tree -F "[#I#P] #{pane_current_command} #{pane_current_path}" -w -Z -f '#{!=:#{window_active},1}' "join-pane -t '%%'"

# move pane from to [-h:yoko,-v:tate]
tmux join-pane -<hv> -s <pane_from> -t <pane_to>

# move window
tmux choose-tree -F "[#I#P] #{pane_current_command} #{pane_current_path}" -w -Z -s "move-window -t '%%'"

# swap(move) window
tmux swap-window -t <window_no>

# create new session
tmux new-session -d -s "$(basename "$(pwd)")" -c "$(pwd)"

# respawn-current-pane [-k:kill existing command,-c:start-directory]
tmux respawn-pane -k -c '#{pane_current_path}' -t .

# respawn-pane [-k:kill existing command,-c:start-directory]
tmux respawn-pane -k -c '#{pane_current_path}' -t <pane_to>

# pipe-pane
tmux pipe-pane -t <pane_from> 'cat | grep '<word>' >> <tty>' ; read ; tmux pipe-pane -t <pane_from>

# capture-pane [-p:print,-S:start-line,-t:pane]
tmux capture-pane -p -S -100 -t <pane_from>

# arrange layout
tmux select-layout tiled

# restore resurrect file
ln -sf <resurrect_file> ~/.local/share/tmux/resurrect/last && tmux run-shell ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh

# relink resurrect file
ln -fs <resurrect_file> ~/.local/share/tmux/resurrect/last
```
$ hv: echo -e "v\nh"
$ resurrect_file: find ~/.local/share/tmux/resurrect/ -type f | head -n 10
$ pane_from: echo "." && \
  tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 1
$ pane_to: echo "." && \
  tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 1
$ tty: tmux lsp -a \
  -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty}" \
  | column -t \
  --- --column 6
;$
