#!/bin/bash
set -e

# OS 依存の生成物を、ホストへ書き込まないコンテナローカル領域へ切り替える。
bash /home/vscode/.config/devcontainer/scripts/mount-container-only-dirs.sh "${PWD}"

# .claude.json のコピー（既存の処理）
claude_config_host=~/.config/claude-config-host.json
if [ ! -f ~/.claude.json ] && [ -f "$claude_config_host" ]; then
	cp "$claude_config_host" ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

# コンテナ用の書き込み可能な .gitconfig にホスト設定を追加
# ホストの gitconfig（user.name / user.email を含む）は /home/vscode/.config/gitconfig-host に
# 読み取り専用でマウントされているため（/tmp 配下は使わない。docs/devcontainer.md 参照）、
# 既存の ~/.gitconfig があっても include を追加する。
gitconfig_host=~/.config/gitconfig-host
if ! git config --global --get-all include.path | grep -Fxq "$gitconfig_host"; then
	git config --global --add include.path "$gitconfig_host"
fi
echo "✓ ホストの git config を設定しました"
git config --global credential.https://github.com.helper '!gh auth git-credential'
git config --global url.https://github.com/.insteadOf git@github.com:

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

if [ ! -f ~/.crit.config.json ]; then
	cat >~/.crit.config.json <<'EOF'
{
  "no_open": true,
  "agent_cmd": "claude --dangerously-skip-permissions -p"
}
EOF
	echo "✓ ~/.crit.config.json を生成しました"
else
	echo "ℹ️ ~/.crit.config.json は既に存在します"
fi
