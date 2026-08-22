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

# Plannotator本体とagent連携（review/annotate skills、Codex Stop hook）を導入する。
# installer自体とreleaseを固定し、downloadしたinstallerのchecksumとrelease provenanceを検証する。
PLANNOTATOR_VERSION=v0.27.6
PLANNOTATOR_INSTALLER_SHA256=b644951c8d556414dacc4a7d70e1b6fd7e5674111ed3f533575aadb1b33424e5
PLANNOTATOR_INSTALLER_URL=https://raw.githubusercontent.com/backnotprop/plannotator/6e20ec78e8481fdc74cd246c53d730cdd1e53ccc/scripts/install.sh
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl -fsSL "$PLANNOTATOR_INSTALLER_URL" -o "$installer"
printf '%s  %s\n' "$PLANNOTATOR_INSTALLER_SHA256" "$installer" | sha256sum --check --status
PLANNOTATOR_SKIP_AGENT_TERMINAL_INSTALL=1 bash "$installer" \
	--version "$PLANNOTATOR_VERSION" --verify-attestation --non-interactive --no-extras
rm -f "$installer"
trap - EXIT
echo "✓ Plannotatorをインストールしました（Effective HTML skillsはAPMで配布）"
