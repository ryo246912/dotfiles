# shellcheck shell=bash
# sandbox / devcontainer から `host-tmux <name> [args...]` で実行を許可する tmux コマンドの定義。
# ホスト側の host-tmux-gate（config/devcontainer/scripts/host-tmux-gate）が source する。
# ここに定義していないコマンドは、ホスト側では一切実行できない。
#
# 追加するには host_tmux_cmd_<name>（name の - は _ にする）という関数を定義する。
# - 引数は gate が [A-Za-z0-9%@._:-] だけ・最大 8 個に制限済み。用途に応じて下の helper で更に検証する
#   - host_tmux_require_pane <pane>       : %3 のような pane ID か
#   - host_tmux_require_count <n> [max]   : 1〜max（既定 10000）の整数か
#   - host_tmux_die <message>             : エラーで終了する
# - tmux はホストで見つかったバイナリを呼ぶ関数になっている
# - send-keys / kill-pane / respawn-pane など、ホストの状態を変えるコマンドは定義しないこと
# 定義を変えたら sandbox 側の作り直しは不要（ホスト側で次の呼び出しから反映される）。

# pane ID・session:window.pane・実行中コマンド・作業ディレクトリ・サイズを一覧表示する。
host_tmux_cmd_list() {
	[ "$#" -eq 0 ] || host_tmux_die "usage: host-tmux list"
	local sep
	sep="$(printf '\t')"
	tmux list-panes -a \
		-F "#{pane_id}${sep}#{session_name}:#{window_index}.#{pane_index}${sep}#{pane_current_command}${sep}#{pane_current_path}${sep}#{pane_width}x#{pane_height}"
}

# 指定した pane の直近 N 行（既定 200 行）を取得する。
host_tmux_cmd_capture() {
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] || host_tmux_die "usage: host-tmux capture <pane> [lines]"
	local lines="${2:-200}"
	host_tmux_require_pane "$1"
	host_tmux_require_count "${lines}" 5000
	tmux capture-pane -p -J -S "-${lines}" -t "$1" | tail -n "${lines}"
}

# 例: window の一覧も許可したい場合はコメントを外す。
# host_tmux_cmd_windows() {
# 	[ "$#" -eq 0 ] || host_tmux_die "usage: host-tmux windows"
# 	tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}'
# }
