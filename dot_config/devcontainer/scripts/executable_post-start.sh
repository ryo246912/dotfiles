#!/bin/bash
set -e

# SSH configを生成（~/.config/ssh/configに配置）
mkdir -p ~/.config/ssh
cat >~/.config/ssh/config <<EOF
Host mac-host
    HostName host.docker.internal
    User ${HOST_USER}
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
EOF

echo "✓ SSH configを生成しました: ~/.config/ssh/config (User: ${HOST_USER})"

# mise trust を実行
mise trust
echo "✓ mise trust を実行しました"
