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

# crit の appPort (127.0.0.1::7842) は host port を Docker に自動採番させているため、
# 実際に割り当てられた port を mac-host 経由の `docker port` で調べ、
# ~/.crit-host-port に記録した上でホストへ通知する（devcontainer を複数同時起動しても
# ポート衝突が起きないようにするため。詳細は docs/crit.md 参照）。
# HOSTNAME はコンテナの short ID（Docker のデフォルトのホスト名）と一致する。
CRIT_HOST_PORT_FILE=~/.crit-host-port
CRIT_HOST_PORT=$(ssh -F ~/.config/ssh/config -o ConnectTimeout=2 -o StrictHostKeyChecking=no mac-host \
	"docker port '${HOSTNAME}' 7842/tcp" 2>/dev/null | tail -n1 | sed -E 's/.*://') || true

if [ -n "${CRIT_HOST_PORT:-}" ]; then
	echo "$CRIT_HOST_PORT" >"$CRIT_HOST_PORT_FILE"
	ssh -F ~/.config/ssh/config -o ConnectTimeout=2 -o StrictHostKeyChecking=no mac-host \
		"macos-notify-cli --title 'crit' --message 'crit UI: http://localhost:${CRIT_HOST_PORT}' --sound Glass" \
		2>/dev/null || true
	echo "✓ crit の host port (${CRIT_HOST_PORT}) を ${CRIT_HOST_PORT_FILE} に記録し、ホストへ通知しました"
else
	rm -f "$CRIT_HOST_PORT_FILE"
	echo "ℹ️ crit の host port 取得をスキップしました（devcontainer 外、または mac-host に接続できない環境）"
fi
