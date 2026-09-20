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

# 鍵パスへのロックを取得する。50回(最大5秒)試して取れなければ諦めて続行する
# (他の devcontainer 初期化が終わるのを無期限に待ってハングするのを避けるため)。
_ssh_key_lock_acquire() {
	local lock="$1" i
	for i in $(seq 1 50); do
		mkdir "$lock" 2>/dev/null && return 0
		sleep 0.1
	done
	echo "⚠ ロック取得がタイムアウトしました。ロック無しで続行します: $lock" >&2
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

# 鍵ペアが無ければ生成する。新規に鍵ペアを生成した場合は 0、既存の鍵をそのまま使った場合は 1 を返す。
# multi-worktree 等で複数の devcontainer が同じ鍵パスへ同時に initializeCommand から触れる
# 可能性があるため、mkdir ロックで生成/同期処理を直列化する。
# ロックを取得できないまま(タイムアウト後)進む場合でも、自分が作っていないロックディレクトリは
# 他プロセスがまだ保持している可能性があるため絶対に rmdir しない(自分が取得できた時だけ解放する)。
ensure_ssh_key() {
	local key="$1" comment="$2" lock="${key}.lock" rc=0 owned=0
	if _ssh_key_lock_acquire "$lock"; then
		owned=1
	fi
	_ensure_ssh_key_locked "$key" "$comment" || rc=$?
	if [ "$owned" -eq 1 ]; then
		rmdir "$lock" 2>/dev/null || true
	fi
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
