#!/bin/bash
set -e

# .claude.json のコピー（既存の処理）
if [ ! -f ~/.claude.json ] && [ -f /tmp/claude-config-host.json ]; then
	cp /tmp/claude-config-host.json ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

# ---- git 設定 -----------------------------------------------------------------
# ホストの ~/.config/git は、コンテナ内でも同じパスに read-only で bind mount している
# (devcontainer.json)。ただしホスト設定をそのまま global 設定として使うと、
# GPG 署名・osxkeychain・push の SSH 書き換えなど「コンテナでは成立しない設定」まで
# 効いてしまい commit / push が失敗する。
# そのため git には GIT_CONFIG_GLOBAL=~/.gitconfig を渡した上で(devcontainer.json)、
#   1. ホスト設定を include 解決した状態で読み出し
#   2. コンテナで壊れるキーを除外して ~/.gitconfig に取り込み
#   3. コンテナ固有の設定を追記
# という手順で ~/.gitconfig を毎回生成し直す。
HOST_GIT_CONFIG="${HOME}/.config/git/config"
CONTAINER_GIT_CONFIG="${HOME}/.gitconfig"

# コンテナに持ち込むと壊れる（または意味を持たない）設定:
#   include.* / includeif.*  : 解決済み。再 include するとホスト設定が丸ごと復活してしまう
#   *.gpgsign / user.signingkey / gpg.*
#                            : GPG 鍵と gpg-agent がコンテナに無く、署名付き commit が必ず失敗する
#   credential.*             : osxkeychain / git-credential-manager がコンテナに存在しない
#                              （代わりに gh の credential helper を下で設定する）
#   core.editor / core.pager / pager.* / delta.* / interactive.difffilter
#                            : nvim / delta を devcontainer には入れていない
#   url.*                    : push を git@github.com: に書き換えるが、GitHub 用の SSH 鍵が
#                              コンテナに無いため push が失敗する（HTTPS + gh token を使う）
is_host_only_git_key() {
	case "$1" in
	include.* | includeif.*) return 0 ;;
	user.signingkey | commit.gpgsign | tag.gpgsign | push.gpgsign | gpg.*) return 0 ;;
	credential.*) return 0 ;;
	core.editor | core.pager | pager.* | delta.* | interactive.difffilter) return 0 ;;
	url.*) return 0 ;;
	*) return 1 ;;
	esac
}

printf '# post-create.sh が生成。手動で編集してもコンテナ再作成時に上書きされる\n' >"${CONTAINER_GIT_CONFIG}"

if [ -f "${HOST_GIT_CONFIG}" ]; then
	# --list -z の出力は "<key>\n<value>\0"（値を持たないキーは "<key>\0"）
	while IFS= read -r -d '' entry; do
		key="${entry%%$'\n'*}"
		if [ "${key}" = "${entry}" ]; then
			value=""
		else
			value="${entry#*$'\n'}"
		fi
		is_host_only_git_key "${key}" && continue
		git config --file "${CONTAINER_GIT_CONFIG}" --add "${key}" "${value}"
	done < <(git config --file "${HOST_GIT_CONFIG}" --includes --list -z)
	echo "✓ ホストの git 設定を取り込みました: ${HOST_GIT_CONFIG}"
else
	echo "⚠️ ホストの git 設定が見つかりません: ${HOST_GIT_CONFIG}"
fi

# コンテナ固有の設定
# - gpgsign: GPG 鍵が無いため明示的に無効化する（ホスト設定は取り込んでいないが、
#   将来ホスト側で有効化されたときに署名待ちで固まらないよう明示しておく）
# - credential: GitHub は gh のトークンで認証する
# - url: SSH 形式の remote も HTTPS に寄せ、gh のトークンで push できるようにする
# - safe.directory: workspace はホストから bind mount されており、uid の食い違いで
#   "dubious ownership" と判定されると git 操作が一切できなくなるため許可する
cat >>"${CONTAINER_GIT_CONFIG}" <<'EOF'

# --- devcontainer 固有の設定 ---
[commit]
	gpgsign = false
[tag]
	gpgsign = false
[credential "https://github.com"]
	helper = !gh auth git-credential
[url "https://github.com/"]
	insteadOf = git@github.com:
	insteadOf = ssh://git@github.com/
[safe]
	directory = *
EOF

# エディタはコンテナに実在するものを設定する（未設定だと commit 時に editor 起動で失敗する）
for candidate in nvim vim nano vi; do
	if command -v "${candidate}" >/dev/null 2>&1; then
		git config --file "${CONTAINER_GIT_CONFIG}" core.editor "${candidate}"
		break
	fi
done

# user.name / user.email が無いと commit できないため、ここで必ず埋まっていることを確認する。
# ホスト設定から取れなかった場合は gh の認証情報から補完する（noreply アドレスを使う）。
if ! git config --file "${CONTAINER_GIT_CONFIG}" --get user.name >/dev/null ||
	! git config --file "${CONTAINER_GIT_CONFIG}" --get user.email >/dev/null; then
	if gh_user=$(gh api user --jq '"\(.login) \(.id)"' 2>/dev/null) && [ -n "${gh_user}" ]; then
		gh_login="${gh_user%% *}"
		gh_id="${gh_user##* }"
		git config --file "${CONTAINER_GIT_CONFIG}" --get user.name >/dev/null ||
			git config --file "${CONTAINER_GIT_CONFIG}" user.name "${gh_login}"
		git config --file "${CONTAINER_GIT_CONFIG}" --get user.email >/dev/null ||
			git config --file "${CONTAINER_GIT_CONFIG}" user.email "${gh_id}+${gh_login}@users.noreply.github.com"
		echo "ℹ️ user.name / user.email を gh の認証情報から補完しました"
	fi
fi

git_user_name="$(git config --file "${CONTAINER_GIT_CONFIG}" --get user.name || true)"
git_user_email="$(git config --file "${CONTAINER_GIT_CONFIG}" --get user.email || true)"
if [ -n "${git_user_name}" ] && [ -n "${git_user_email}" ]; then
	echo "✓ .gitconfig を生成しました (user.name=${git_user_name}, user.email=${git_user_email})"
else
	echo "⚠️ git の user.name / user.email を設定できませんでした。このままでは commit できません"
	echo "   ホスト側の ~/.config/git/config に [user] name / email があるか確認してください"
	echo "   （docs/devcontainer.md「git 設定」を参照）"
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
