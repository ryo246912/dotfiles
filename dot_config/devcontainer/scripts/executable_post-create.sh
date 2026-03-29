#!/bin/bash
set -e

# .claude.json のコピー（既存の処理）
if [ ! -f ~/.claude.json ] && [ -f /tmp/claude-config-host.json ]; then
	cp /tmp/claude-config-host.json ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

account2_dir="${HOME}/.claude-account2"
mkdir -p "${account2_dir}"

if [ ! -e "${account2_dir}/projects" ] && [ ! -L "${account2_dir}/projects" ] && [ -d "${HOME}/.claude/projects" ]; then
	ln -s ../.claude/projects "${account2_dir}/projects"
	echo "✓ .claude-account2/projects を共有しました"
else
	echo "ℹ️ .claude-account2/projects の共有はスキップしました"
fi

if [ ! -e "${account2_dir}/settings.json" ] && [ ! -L "${account2_dir}/settings.json" ] && [ -f "${HOME}/.claude/settings.json" ]; then
	ln -s ../.claude/settings.json "${account2_dir}/settings.json"
	echo "✓ .claude-account2/settings.json を共有しました"
else
	echo "ℹ️ .claude-account2/settings.json の共有はスキップしました"
fi
