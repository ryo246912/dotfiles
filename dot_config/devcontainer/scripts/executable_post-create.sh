#!/bin/bash
set -e

# .claude.json のコピー（既存の処理）
if [ ! -f ~/.claude.json ] && [ -f /tmp/claude-config-host.json ]; then
	cp /tmp/claude-config-host.json ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

# コンテナ用の書き込み可能な .gitconfig を生成
# ホストの gitconfig は /tmp/gitconfig-host に読み取り専用でマウントされているため、
# コンテナ内に書き込み可能な .gitconfig を作成し、ホスト設定をインクルードする
if [ ! -f ~/.gitconfig ]; then
	cat >~/.gitconfig <<'EOF'
[include]
    path = /tmp/gitconfig-host
[credential "https://github.com"]
    helper = !gh auth git-credential
[url "https://github.com/"]
    insteadOf = git@github.com:
EOF
	echo "✓ .gitconfig を生成しました"
else
	echo "ℹ️ .gitconfig は既に存在します"
fi
