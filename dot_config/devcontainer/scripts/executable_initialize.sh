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

# 鍵ペアが無ければ生成する。新規に鍵ペアを生成した場合は 0、既存の鍵をそのまま使った場合は 1 を返す。
# 秘密鍵はあるが .pub だけ無い(削除・復元漏れ等)場合は、mounts の .pub 側 source が欠けて
# devcontainer up が失敗するため、秘密鍵から公開鍵だけを再構成する(鍵ペア自体は再生成しない)。
ensure_ssh_key() {
	local key="$1" comment="$2"
	if [ -f "$key" ]; then
		if [ ! -f "${key}.pub" ]; then
			# `>` によるリダイレクトはコマンド実行前にファイルを作成するため、ssh-keygen が
			# 失敗しても空の .pub が残ってしまい、次回以降そのまま「存在する」と誤判定されて
			# 再構成がスキップされ続ける。一時ファイルに書いてから成功時のみ rename する。
			local pub_tmp
			pub_tmp="${key}.pub.tmp.$$"
			if ! ssh-keygen -y -f "$key" >"$pub_tmp"; then
				rm -f "$pub_tmp"
				echo "✗ 秘密鍵からの公開鍵の再構成に失敗しました: ${key}" >&2
				return 1
			fi
			mv "$pub_tmp" "${key}.pub"
			echo "✓ 秘密鍵から公開鍵を再構成しました: ${key}.pub"
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
