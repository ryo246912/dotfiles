#!/bin/bash
set -e

# SSH configを生成（~/.config/ssh/configに配置）
mkdir -p ~/.config/ssh
SSH_CONFIG=~/.config/ssh/config
touch "${SSH_CONFIG}"
if ! grep -q '^Host mac-host$' "${SSH_CONFIG}"; then
cat >>"${SSH_CONFIG}" <<EOF
Host mac-host
    HostName host.docker.internal
    User ${HOST_USER}
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
EOF
echo "✓ SSH configを生成しました: ~/.config/ssh/config (User: ${HOST_USER})"
else
echo "ℹ️ SSH config (mac-host) は既に存在します"
fi

# mise trust を実行
mise trust
echo "✓ mise trust を実行しました"

# review UI の appPort は host port を Docker に自動採番させているため、
# 実際の port を mac-host 経由で取得してファイルへ記録し、ホストへ通知する。
# SSH は非対話・timeout 付きにして、devcontainer 外では静かにスキップする。
SSH_OPTS=(-F ~/.config/ssh/config -o BatchMode=yes -o ConnectTimeout=2)

record_review_port() { # $1: tool name, $2: container port
	local tool="$1" container_port="$2"
	local host_port_file="${HOME}/.${tool}-host-port"
	local host_port=""

	# 一時的な SSH failure で有効な cache を失わないよう retry する。
	for _ in 1 2; do
		host_port=$(timeout 5 ssh "${SSH_OPTS[@]}" mac-host \
			"docker port '${HOSTNAME}' ${container_port}/tcp" 2>/dev/null | tail -n1 | sed -E 's/.*://') || true
		[ -n "$host_port" ] && break
		sleep 1
	done

	if [ -n "$host_port" ]; then
		echo "$host_port" >"$host_port_file"
		timeout 5 ssh "${SSH_OPTS[@]}" mac-host \
			"macos-notify-cli --title '${tool}' --message '${tool} UI: http://localhost:${host_port}' --sound Glass" \
			2>/dev/null || true
		echo "✓ ${tool} の host port (${host_port}) を ${host_port_file} に記録し、ホストへ通知しました"
	else
		rm -f "$host_port_file"
		echo "ℹ️ ${tool} の host port 取得をスキップしました（devcontainer 外、または mac-host に接続できない環境）"
	fi
}

record_review_port crit 7842
record_review_port difit 4966
