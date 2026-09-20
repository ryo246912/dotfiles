#!/bin/bash
set -e

# devcontainer.json の initializeCommand としてホスト側で実行されるスクリプト。
#
# devcontainer.json の `mounts` は `docker run --mount` で処理されるため、レガシーな `-v` と
# 違って source パスが存在しないとコンテナ作成自体が失敗する（target 側は常にコンテナ内で
# 新規に作られるので問題にならない）。initializeCommand はコンテナ作成前にホスト側で実行される
# ため、ここで mounts の source を全て事前に用意しておくことでその失敗を防ぐ。
#
# 注意: devcontainer.json の mounts を変更したら、このスクリプトも合わせて更新すること。

ensure_dir() {
	[ -e "$1" ] || {
		mkdir -p "$1"
		echo "✓ 作成(ディレクトリ): $1"
	}
}

ensure_empty_file() {
	[ -e "$1" ] || {
		mkdir -p "$(dirname "$1")"
		touch "$1"
		echo "✓ 作成(空ファイル): $1"
	}
}

ensure_json_file() {
	[ -e "$1" ] || {
		mkdir -p "$(dirname "$1")"
		echo '{}' >"$1"
		echo "✓ 作成(空JSON): $1"
	}
}

# 自分の PID を書き込んだ「宣言用」ディレクトリを一時パスに用意してから、それを
# mv で $lock へ公開する。mkdir してから別途 pid を書き込む(2手順に分かれた)
# 従来方式だと、mkdir 成功後にスケジューリング等で長時間止まった場合、その間に
# 他プロセスがこのロックを「pid が無いままの孤児」とみなして奪ってしまい、後から
# 目覚めた自分が pid を書き込むと今度は相手の(新しい)ロックを上書きしてしまう、
# という競合があった。pid を書いた状態のディレクトリを一括で公開すれば、$lock が
# 存在する瞬間には必ず正しい pid が入っており、この隙間が生まれない。
#
# mv の宛先が既に(別プロセスの)ディレクトリとして存在する場合、mv は「その中へ
# 移動」するだけで置き換えてくれないため、公開後に ${lock}/pid を読み直して本当に
# 自分の PID になっているか確認する。なっていなければ自分の宣言用ディレクトリが
# 誤って相手のロックの中へネストされているので、それを片付けてから諦める
# (呼び出し元はループを継続し、次の機会に取り直す)。
_ssh_key_lock_publish() {
	local lock="$1" tmp
	tmp="${lock}.claim.$$"
	rm -rf "$tmp" 2>/dev/null
	mkdir "$tmp" 2>/dev/null || return 1
	if ! echo "$$" >"${tmp}/pid" 2>/dev/null; then
		rm -rf "$tmp" 2>/dev/null
		return 1
	fi
	if ! mv "$tmp" "$lock" 2>/dev/null; then
		rm -rf "$tmp" 2>/dev/null
		return 1
	fi
	if [ "$(cat "${lock}/pid" 2>/dev/null || true)" = "$$" ]; then
		return 0
	fi
	rm -rf "${lock}/$(basename "$tmp")" 2>/dev/null
	return 1
}

# ロックの中身を自分専用の名前へ mv で原子的に退避し、実際に死んでいた(あるいは
# pid ファイルが無かった)場合だけ破棄する。退避した中身が実は生きていた場合
# (競合)は、$lock が空いていれば元に戻す。呼び出し元はこの後どのみちループを
# 継続すればよい(奪取できていれば次の _ssh_key_lock_publish で自分が取得できる)。
#
# 「死んでいる/孤児だと判断してから rm -rf する」のように確認と削除の間に隙間が
# あると、その隙間で別プロセスが同じロックを正当に奪って再取得していた場合、その
# 生きているロックごと消してしまう(TOCTOU)。rm ではなく mv で退避してから改めて
# 中身を検査することでこれを避ける。
_ssh_key_lock_try_steal() {
	local lock="$1" stolen pid
	stolen="${lock}.stale.$$"
	if mv "$lock" "$stolen" 2>/dev/null; then
		pid="$(cat "${stolen}/pid" 2>/dev/null || true)"
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			if [ ! -e "$lock" ]; then
				mv "$stolen" "$lock" 2>/dev/null || rm -rf "$stolen" 2>/dev/null
			else
				rm -rf "$stolen" 2>/dev/null
			fi
		else
			rm -rf "$stolen" 2>/dev/null
		fi
	fi
}

# 鍵パスへのロックを取得する。50回(最大5秒)試して取れなければ諦める。
# ロックディレクトリには取得者の PID を書き込み、取得できなかった場合はその PID がまだ
# 生きているか確認する: 既に死んでいれば(クラッシュ等で残った古いロック)奪って取り直す。
# 生きていれば、鍵ファイルを同時に触ると壊れるため、諦めて呼び出し元にエラーを返す
# (鍵の書き換えを試みるより、その回の処理をスキップする方が安全)。
#
# mkdir 成功後・pid 書き込み前にプロセスが死ぬと、pid ファイルの無いロックが孤児として
# 残る。これは「pid が無い = 死んでいる」と即断せず(mkdir 直後の一瞬はまだ書き込み中の
# 可能性があるため)、pid ファイルが無い状態が何回か(0.5秒相当)続いて初めて孤児と
# みなして奪取する。放置すると誰も永久に取得できなくなるため、これも必ず処理する。
_ssh_key_lock_acquire() {
	local lock="$1" i pid no_pid_streak=0
	for i in $(seq 1 50); do
		if _ssh_key_lock_publish "$lock"; then
			return 0
		fi
		if [ -f "${lock}/pid" ]; then
			no_pid_streak=0
			pid="$(cat "${lock}/pid" 2>/dev/null || true)"
			if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
				_ssh_key_lock_try_steal "$lock"
				continue
			fi
		else
			no_pid_streak=$((no_pid_streak + 1))
			if [ "$no_pid_streak" -ge 5 ]; then
				_ssh_key_lock_try_steal "$lock"
				no_pid_streak=0
				continue
			fi
		fi
		sleep 0.1
	done
	return 1
}

# ensure_ssh_key の本体(ロック取得後に呼ばれる)。
_ensure_ssh_key_locked() {
	local key="$1" comment="$2"
	if [ -f "$key" ]; then
		# 秘密鍵から公開鍵を導出して .pub と同期する。.pub が無い場合(削除・復元漏れ)だけでなく、
		# 秘密鍵だけ手動で差し替えられて .pub が古い(鍵ペアの不一致)場合も、常に導出し直して
		# 比較することでまとめて解消する。
		# `-P ""` でパスフレーズ入力を待たせず即エラーにする: initializeCommand は非対話実行のため、
		# 対話プロンプトが出るとコンテナ作成が無期限にハングしてしまう。
		local pub_tmp="${key}.pub.tmp.$$"
		if ! ssh-keygen -y -P "" -f "$key" >"$pub_tmp" 2>/dev/null; then
			rm -f "$pub_tmp"
			echo "✗ 秘密鍵からの公開鍵の導出に失敗しました(パスフレーズ付き秘密鍵は非対応): ${key}" >&2
			return 1
		fi
		if [ ! -f "${key}.pub" ] || ! cmp -s "$pub_tmp" "${key}.pub"; then
			mv "$pub_tmp" "${key}.pub"
			echo "✓ 秘密鍵から公開鍵を(再)構成しました: ${key}.pub"
		else
			rm -f "$pub_tmp"
		fi
		return 1
	fi
	mkdir -p "$(dirname "$key")"
	# 秘密鍵が無いのに孤立した .pub だけ残っていると、ssh-keygen が対話的な上書き確認で
	# 止まってしまうため、鍵ペア生成前に削除しておく。
	rm -f "${key}.pub"
	# この関数は `if ensure_ssh_key ...; then` や `... || rc=$?` のように呼び出し元で
	# 常にガードされているため、bash の仕様上 `set -e` はここでは効かない(ガードされた
	# コマンド内では無効になる)。そのため ssh-keygen の失敗を明示的に検査しないと、
	# 鍵ファイルが実際には存在しないのに "✓ 生成しました" と表示して 0 を返してしまう。
	# 既存鍵がある場合の 1(no-op)とは区別できる 2 を返し、呼び出し元(トップレベル)で
	# 明示的にスクリプト全体を止められるようにする。
	if ! ssh-keygen -t ed25519 -N "" -f "$key" -C "$comment" -q; then
		echo "✗ SSH鍵の生成に失敗しました: $key" >&2
		return 2
	fi
	echo "✓ SSH鍵を生成しました: $key"
	return 0
}

# 鍵ペアが無ければ生成する。新規に鍵ペアを生成した場合は 0、既存の鍵をそのまま使った場合(または
# ロック取得失敗などで処理をスキップした場合)は 1 を返す。
# multi-worktree 等で複数の devcontainer が同じ鍵パスへ同時に initializeCommand から触れる
# 可能性があるため、鍵の生成/同期処理を直列化する。
#
# `flock` が使えるならそちらを使う: プロセスが保持する fd に紐づく OS レベルの
# アドバイザリロックで、mkdir/pid ファイルベースの自前実装と違って TOCTOU が原理的に無く、
# プロセスが死ねば OS が自動的に解放するため孤児ロックも発生しない。WSL2/Linux では
# util-linux の一部として標準で入っていることが多い。
# `flock` が無い環境(素の macOS 等)向けには、`_ssh_key_lock_acquire` による
# mkdir ベースのフォールバックを用意している。こちらは死んだ/孤児ロックの回収を
# ベストエフォートで行うが、`flock` ほど厳密ではない(ごく狭い理論上の競合が残りうる)。
ensure_ssh_key() {
	# `local key=... lock="${key}.lock"` のように同じ local 文の中で書くと、右辺の ${key} は
	# この文で代入する新しい値ではなく代入前の(未設定の)値を参照してしまうため、
	# 必ず key を確定させた後に別の local 文で lock を組み立てる。
	local key="$1" comment="$2" rc=0
	local lock="${key}.lock"
	if command -v flock >/dev/null 2>&1; then
		(
			exec 9>"$lock"
			if ! flock -w 5 9; then
				echo "✗ ロック取得がタイムアウトしたため、鍵の処理をスキップしました: ${key}" >&2
				exit 1
			fi
			_ensure_ssh_key_locked "$key" "$comment"
		) || rc=$?
		return "$rc"
	fi
	if ! _ssh_key_lock_acquire "$lock"; then
		echo "✗ ロック取得がタイムアウトしたため、鍵の処理をスキップしました: ${key}" >&2
		return 1
	fi
	_ensure_ssh_key_locked "$key" "$comment" || rc=$?
	rm -rf "$lock" 2>/dev/null || true
	return "$rc"
}

# .config/* (gh・ccusage・mise はツール側が初回実行時に作るディレクトリ。未実行だと無いことがある)
ensure_dir ~/.config/gh
ensure_dir ~/.config/ccusage
ensure_dir ~/.config/mise

# .ssh
ensure_empty_file ~/.ssh/known_hosts
# devcontainer専用のSSH鍵（ホスト通知用。docs/devcontainer.md 参照）
# ensure_ssh_key の戻り値: 0=新規生成, 1=既存鍵のまま(no-op)/取得失敗等でスキップ,
# 2=新規鍵の生成自体が失敗(回復不能。mount source が用意できないため続けても
# devcontainer up がどのみち失敗するので、ここで明示的に止める)。
notify_rc=0
ensure_ssh_key ~/.ssh/id_docker_devcontainer "devcontainer host notify" || notify_rc=$?
[ "$notify_rc" -eq 2 ] && exit 1
# devcontainer専用のSSH鍵（コミット署名用。docs/devcontainer.md 参照）
sign_rc=0
ensure_ssh_key ~/.ssh/id_docker_devcontainer_sign "devcontainer commit signing" || sign_rc=$?
[ "$sign_rc" -eq 2 ] && exit 1
if [ "$sign_rc" -eq 0 ]; then
	echo "  → GitHub Settings > SSH and GPG keys > New SSH key (Key type: Signing Key) に以下を登録してください:"
	cat ~/.ssh/id_docker_devcontainer_sign.pub
fi

# AI agent configs（初回セットアップ前でコンテナを起動できるよう、無ければ空の状態を用意する）
ensure_dir ~/.claude
ensure_json_file ~/.claude/settings.json
ensure_json_file ~/.claude.json
ensure_dir ~/.claude-account2
ensure_dir ~/.agents
ensure_dir ~/.codex
ensure_dir ~/.copilot
ensure_dir ~/.coderabbit
