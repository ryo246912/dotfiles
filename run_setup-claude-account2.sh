#!/bin/bash
# Claude account2 (CLAUDE_CONFIG_DIR=~/.claude-account2) で account1 の設定を共有する。
# ccmanager preset の Claude A2 はこのディレクトリを CLAUDE_CONFIG_DIR に指定して起動する。
# devcontainer 側は post-create.sh で同じ処理を行う。

account2_dir="${HOME}/.claude-account2"
mkdir -p "${account2_dir}"

for shared_entry in projects settings.json agents skills plugins; do
	if [ ! -e "${account2_dir}/${shared_entry}" ] && [ ! -L "${account2_dir}/${shared_entry}" ] && [ -e "${HOME}/.claude/${shared_entry}" ]; then
		ln -sv "../.claude/${shared_entry}" "${account2_dir}/${shared_entry}"
	fi
done
