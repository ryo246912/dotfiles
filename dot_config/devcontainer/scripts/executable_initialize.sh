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

# ロックの中身を自分専用の名前へ mv で原子的に退避し、実際に死んでいた(あるいは
# pid ファイルが無かった)場合だけ破棄する。退避した中身が実は生きていた場合
# (競合)は、$lock が空いていれば元に戻す。呼び出し元はこの後どのみちループを
# 継続すればよい(奪取できていれば次の mkdir で自分が取得できる)。
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
		if mkdir "$lock" 2>/dev/null; then
			echo "$$" >"${lock}/pid" 2>/dev/null || true
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
	ssh-keygen -t ed25519 -N "" -f "$key" -C "$comment" -q
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
ensure_ssh_key ~/.ssh/id_docker_devcontainer "devcontainer host notify" || true
# devcontainer専用のSSH鍵（コミット署名用。docs/devcontainer.md 参照）
if ensure_ssh_key ~/.ssh/id_docker_devcontainer_sign "devcontainer commit signing"; then
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
