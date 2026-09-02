#!/bin/bash
set -e

# .claude.json のコピー（既存の処理）
# ホストの .claude.json は /home/vscode/.config/claude-config-host.json に読み取り専用でマウント
# されている（/tmp 配下は tmpfs にシャドウされるため使わない。docs/devcontainer.md 参照）
claude_config_host=~/.config/claude-config-host.json
if [ ! -f ~/.claude.json ] && [ -f "$claude_config_host" ]; then
	cp "$claude_config_host" ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

# コンテナ用の書き込み可能な .gitconfig を生成
# ホストの gitconfig は /home/vscode/.config/gitconfig-host に読み取り専用でマウントされて
# いるため（/tmp 配下は使わない。docs/devcontainer.md 参照）、コンテナ内に書き込み可能な
# .gitconfig を作成し、ホスト設定をインクルードする
#
# gitconfig-host が無い場合、include先を書いてしまうと以降すべての git コマンドが
# `fatal: bad config line ...: No such file or directory` で失敗する。mounts の変更が
# 反映されないまま古いコンテナを再利用した場合などにこの状態になり得るため、その場合は
# include を足さずに警告する（詳細は docs/devcontainer.md 参照）。
gitconfig_host=~/.config/gitconfig-host
if [ ! -f "$gitconfig_host" ]; then
	echo "⚠️ ${gitconfig_host} が見つかりません。コンテナを rebuild してください（docs/devcontainer.md 参照）"
elif [ ! -f ~/.gitconfig ]; then
	cat >~/.gitconfig <<EOF
[include]
    path = ${gitconfig_host}
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
