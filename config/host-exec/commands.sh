# shellcheck shell=bash
# sandbox / devcontainer から `host-exec <name> [args...]` でホストに実行させてよいコマンドの定義。
# ホスト側の host-exec-gate（config/devcontainer/scripts/host-exec-gate）が source する。
# mac-host 用の鍵では、ここに定義していないコマンドはホストで一切実行できない。
#
# 追加するには host_exec_cmd_<name>（name の - は _ にする）という関数を定義する。
# - 引数は任意の文字列のまま届く（シェルには通っていない）。必ず関数の中で検証してから使う
#   - host_exec_require_int <value> [max]           : 1〜max（既定 65535）の整数か
#   - host_exec_require_match <value> <regex> [what] : 正規表現に一致するか
#   - host_exec_die <message>                        : エラーで終了する
# - 引数を eval したり `sh -c` に渡したりしない。コマンドの引数としてだけ使う
# - workspace のコードを実行するコマンド（pytest / npm test / make など）は、sandbox が workspace を
#   書き換えられる以上「ホストで任意のコードを実行できる」のと同じになる。足すなら影響を理解した上で
# 定義を変えたら sandbox / devcontainer の作り直しは不要（ホスト側で次の呼び出しから反映される）。

# ---------------------------------------------------------------------------
# 通知
# ---------------------------------------------------------------------------

# macOS の通知を出す（Claude Code の hooks・crit の再レビュー通知）。
# usage: notify <title> <message> [sound]
host_exec_cmd_notify() {
	[ "$#" -ge 2 ] && [ "$#" -le 3 ] || host_exec_die "usage: host-exec notify <title> <message> [sound]"
	[ "${#1}" -le 200 ] && [ "${#2}" -le 1000 ] || host_exec_die "title or message is too long"
	local sound="${3:-Glass}"
	host_exec_require_match "${sound}" '^[A-Za-z]{1,32}$' sound
	macos-notify-cli --title "$1" --message "$2" --sound "${sound}"
}

# ---------------------------------------------------------------------------
# plannotator / crit
# ---------------------------------------------------------------------------

# ホストのブラウザでローカルの URL を開く（plannotator-browser）。localhost 宛てだけ許可する。
# usage: open-url <http://localhost:PORT/...>
host_exec_cmd_open_url() {
	[ "$#" -eq 1 ] || host_exec_die "usage: host-exec open-url <url>"
	host_exec_require_match "$1" '^https?://(localhost|127\.0\.0\.1):[0-9]{1,5}([/?#][A-Za-z0-9._~:/?#@!$&()*+,;=%-]*)?$' url
	open "$1"
}

# ホストの 127.0.0.1:<port> が待ち受けているか（plannotator の reverse tunnel の確認）。
# usage: port-check <port>
host_exec_cmd_port_check() {
	[ "$#" -eq 1 ] || host_exec_die "usage: host-exec port-check <port>"
	host_exec_require_int "$1" 65535
	nc -z 127.0.0.1 "$1"
}

# devcontainer の公開 port を調べる（post-start.sh が crit の host port を記録する）。
# usage: docker-port <container-id> <port/proto>
host_exec_cmd_docker_port() {
	[ "$#" -eq 2 ] || host_exec_die "usage: host-exec docker-port <container-id> <port/tcp>"
	host_exec_require_match "$1" '^[0-9a-f]{12,64}$' container-id
	host_exec_require_match "$2" '^[0-9]{1,5}/(tcp|udp)$' port
	docker port "$1" "$2"
}

# ---------------------------------------------------------------------------
# tmux（tmux skill / host-tmux）。ホスト側 tmux の状態を変えるもの（send-keys 等）は足さない
# ---------------------------------------------------------------------------

# pane ID・session:window.pane・実行中コマンド・作業ディレクトリ・サイズを一覧表示する。
# usage: tmux-list
host_exec_cmd_tmux_list() {
	[ "$#" -eq 0 ] || host_exec_die "usage: host-exec tmux-list"
	local sep
	sep="$(printf '\t')"
	# 非対話 SSH では UTF-8 の locale が無く、tmux がタブを _ に置き換えるため -u を付ける。
	tmux -u list-panes -a \
		-F "#{pane_id}${sep}#{session_name}:#{window_index}.#{pane_index}${sep}#{pane_current_command}${sep}#{pane_current_path}${sep}#{pane_width}x#{pane_height}"
}

# 指定した pane の直近 N 行（既定 200 行）を取得する。
# usage: tmux-capture <%pane> [lines]
host_exec_cmd_tmux_capture() {
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] || host_exec_die "usage: host-exec tmux-capture <pane> [lines]"
	local lines="${2:-200}"
	host_exec_require_match "$1" '^%[0-9]{1,6}$' "pane (an ID such as %3; run: host-tmux list)"
	host_exec_require_int "${lines}" 5000
	tmux -u capture-pane -p -J -S "-${lines}" -t "$1" | tail -n "${lines}"
}

# ---------------------------------------------------------------------------
# 例: 追加したいコマンド（コメントを外して使う）
# ---------------------------------------------------------------------------

# ホストで pytest を走らせる例。workspace のテストコードがホストで動く＝ sandbox から
# ホストで任意のコードを実行できるのと同じなので、許可する場合はディレクトリを固定し、影響を理解した上で。
# usage: pytest <test-path-under-allowed-dir> [-k <expr>]
# host_exec_cmd_pytest() {
# 	local root="${HOME}/src/myproject"   # 実行を許可するリポジトリ
# 	[ "$#" -ge 1 ] || host_exec_die "usage: host-exec pytest <path> [-k expr]"
# 	host_exec_require_match "$1" '^tests(/[A-Za-z0-9_.-]+)*(::[A-Za-z0-9_]+)*$' path
# 	if [ "$#" -eq 3 ]; then
# 		[ "$2" = -k ] || host_exec_die "only -k is allowed"
# 		host_exec_require_match "$3" '^[A-Za-z0-9_ ]{1,100}$' expression
# 	elif [ "$#" -ne 1 ]; then
# 		host_exec_die "usage: host-exec pytest <path> [-k expr]"
# 	fi
# 	cd "${root}" && pytest "$@"
# }
