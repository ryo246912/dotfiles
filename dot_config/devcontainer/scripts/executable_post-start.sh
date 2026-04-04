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

echo "ℹ️ Browser bridge の例:"
echo "  - slot 一覧: ./dot_local/bin/executable_browser-cli list"
echo "  - host 起動: ssh mac-host \"\$(./dot_local/bin/executable_browser-cli host-command start slot1)\""
echo "  - 接続確認: ./dot_local/bin/executable_browser-cli status slot1"
