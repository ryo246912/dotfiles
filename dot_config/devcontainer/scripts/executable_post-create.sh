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

# claude-account2 ディレクトリを作成
account2_dir="${HOME}/.claude-account2"
mkdir -p "${account2_dir}"

for shared_entry in projects settings.json agents skills plugins; do
	if [ ! -e "${account2_dir}/${shared_entry}" ] && [ ! -L "${account2_dir}/${shared_entry}" ] && [ -e "${HOME}/.claude/${shared_entry}" ]; then
		ln -s "../.claude/${shared_entry}" "${account2_dir}/${shared_entry}"
		echo "✓ .claude-account2/${shared_entry} を共有しました"
	else
		echo "ℹ️ .claude-account2/${shared_entry} の共有はスキップしました"
	fi
done

# plannotator: プラン/コードレビュー用ブラウザ注釈ツール
# ~/.codex 等のエージェント設定ディレクトリはコンテナ起動後にマウントされるため、
# Dockerfileのbuild時ではなくここでインストールし、Codexの自動検出・設定を効かせる。
# - sem(semantic diff)はmiseで別途管理するため PLANNOTATOR_SKIP_SEM_INSTALL でスキップ
# - annotateモード用のagent-terminal runtimeはコードレビュー用途では不要なためスキップ
# - Claude Code側の /plannotator-review 等は ~/.claude/skills/ への配置だけで動くため
#   marketplaceプラグインの有効化は行わない
PLANNOTATOR_SKIP_SEM_INSTALL=1 PLANNOTATOR_SKIP_AGENT_TERMINAL_INSTALL=1 \
	curl -fsSL https://plannotator.ai/install.sh | bash -s -- --non-interactive --no-extras
echo "✓ plannotator をインストール/設定しました"
