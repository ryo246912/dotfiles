#!/bin/bash
set -e

# OneCLI が有効な場合は、HTTPS MITM gateway の公開 CA をシステム trust store に追加する。
# CA 自体は secret ではないため公開 endpoint から取得する。失敗時に不完全な proxy 設定で
# AI agent を起動しないよう、ONECLI_PROXY_URL 設定時はエラーを明示して停止する。
if [ -n "${ONECLI_PROXY_URL:-}" ]; then
	onecli_url="${ONECLI_URL:-http://host.docker.internal:10254}"
	tmp_ca="$(mktemp)"
	trap 'rm -f "$tmp_ca"' EXIT
	curl --fail --silent --show-error --noproxy '*' \
		"${onecli_url%/}/v1/gateway/ca" >"$tmp_ca"
	sudo install -m 0644 "$tmp_ca" /usr/local/share/ca-certificates/onecli-gateway.crt
	sudo update-ca-certificates
	rm -f "$tmp_ca"
	trap - EXIT
	echo "✓ OneCLI gateway CA を登録しました"
fi

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
