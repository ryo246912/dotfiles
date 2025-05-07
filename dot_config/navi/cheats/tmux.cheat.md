```sh
% tmux
# keys
tmux list-keys | less -iRMW --use-color

# list-panes
tmux list-panes -s -F "#S:#I.#P [#{b:pane_current_path}] [#{pane_current_command}] [#{pane_width}x#{pane_height}] #{pane_current_path} #{pane_tty} [history #{history_size}/#{history_limit}, #{history_bytes} bytes]" | column -t

# pane move [-h:yoko,-v:tate]
tmux join-pane -<hv> -s <pane_from> -t <pane_to>

# respawn-current-pane [-k:kill existing command,-c:start-directory]
tmux respawn-pane -k -c '#{pane_current_path}' -t .

# respawn-pane [-k:kill existing command,-c:start-directory]
tmux respawn-pane -k -c '#{pane_current_path}' -t <pane_to>

# window move
tmux swap-window -t <window_no>

# pipe-pane
tmux pipe-pane -t <pane_from> 'cat | grep '<word>' >> <tty>' ; read ; tmux pipe-pane -t <pane_from>
```
$ hv: echo -e "v\nh"
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
