#!/bin/bash
set -e

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

# コミット署名: ホストの個人GPG秘密鍵はコンテナにマウントしていないため、
# include した host config の GPG 署名設定を devcontainer 専用の SSH 鍵で上書きする
# （書き込み順の後勝ちで include.path より優先される。詳細は docs/devcontainer.md 参照）。
signing_key=~/.ssh/id_docker_devcontainer_sign
# .pub ファイルの中身をそのまま信用せず、秘密鍵から都度公開鍵を導出して使う。
# こうすることで、.pub が秘密鍵と不一致(手動差し替え等)の場合や、秘密鍵がパスフレーズ付きで
# 非対話に使えない場合(-P "" での導出が失敗する)を、同じ判定でまとめて弾ける。
signing_pubkey=""
if [ -f "${signing_key}" ]; then
	signing_pubkey="$(ssh-keygen -y -P "" -f "${signing_key}" 2>/dev/null)" || signing_pubkey=""
fi
if [ -n "${signing_pubkey}" ]; then
	# 以前このコンテナで post-create.sh が失敗分岐(署名鍵が使えない状態)を通っていた場合、
	# ~/.gitconfig に commit.gpgsign=false が書き込まれたまま残る。再実行時に鍵が使える
	# ようになっていても、この分岐では signingkey 等しか更新しないため、明示的に true へ
	# 戻さないと署名が無効なままになってしまう。
	git config --global commit.gpgsign true
	git config --global gpg.format ssh
	git config --global user.signingkey "${signing_key}"
	allowed_signers=~/.config/git/allowed_signers
	mkdir -p "$(dirname "$allowed_signers")"
	# namespaces="git" で git の署名/検証以外(file署名等)への流用を防ぐ(GitLab公式手順と同じ制約)
	printf '%s namespaces="git" %s\n' "$(git config user.email)" "$signing_pubkey" >"$allowed_signers"
	git config --global gpg.ssh.allowedSignersFile "$allowed_signers"
	echo "✓ devcontainer専用のSSH鍵でコミット署名を設定しました"
else
	# include した host config には commit.gpgsign=true と GPG 鍵の signingkey が残っているが、
	# GPG秘密鍵はコンテナにマウントしていないため、無効化しないと commit のたびに
	# "secret key not available" で失敗する。署名鍵が非対話で使えない(パスフレーズ付き等)場合も
	# 同様にここに落ちるため、署名設定だけ有効なまま commit が壊れる状態を防げる。
	git config --global commit.gpgsign false
	echo "ℹ️ devcontainer用の署名鍵(${signing_key})が見つからないか非対話で使用できないため、コミット署名を無効化しました"
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
