#!/bin/bash
set -e

# git の identity / 署名設定は、他の補助的な処理（生成物の分離・Lefthook）より先に行う。
# このスクリプトは set -e のため、後段のどれかが失敗すると以降の処理が実行されず、
# ~/.gitconfig が作られないまま commit 時に "Author identity unknown" になってしまう。

# コンテナ用の書き込み可能な .gitconfig にホスト設定を追加
# ホストの gitconfig（user.name / user.email を含む）は /home/vscode/.config/gitconfig-host に
# 読み取り専用でマウントされているため（/tmp 配下は使わない。docs/devcontainer.md 参照）、
# 既存の ~/.gitconfig があっても include を追加する。
gitconfig_host=~/.config/gitconfig-host
# include.path が読めないパスを指していると、git は警告ではなく
# "fatal: unable to access ...: Too many levels of symbolic links" で即死し、
# status / diff を含む全コマンドが使えなくなる（core.excludesfile は warning で済む）。
# そのため読めることを確認してから登録し、読めない場合は登録しない。
if [ -r "$gitconfig_host" ]; then
	if ! git config --global --get-all include.path | grep -Fxq "$gitconfig_host"; then
		git config --global --add include.path "$gitconfig_host"
	fi
	echo "✓ ホストの git config を設定しました"
else
	# 前回の実行で登録済みなら取り除く。壊れた include を残すと git の全コマンドが fatal に
	# なるため、ホスト設定を取り込めないことより優先する。
	#
	# 注意: ここで git config は使えない。--get-all も --unset-all も壊れた include を
	# 展開しようとして同じ fatal で落ちるため、git は自分で壊れた include を外せない。
	# そのため ~/.gitconfig を直接書き換える。
	gitconfig_file="${HOME}/.gitconfig"
	if [ -f "$gitconfig_file" ] && grep -Fq -- "$gitconfig_host" "$gitconfig_file"; then
		gitconfig_tmp="${gitconfig_file}.tmp.$$"
		# 置換で権限が広がらないよう元のモードを引き継ぐ。~/.gitconfig は credential
		# helper の設定等を含みうるため、umask 任せにすると 0600 が 0644 になる。
		# -L で symlink を辿る。付けないと symlink 自身のモード(777)を拾ってしまい、
		# 実体を 777 に広げてしまう。
		gitconfig_mode="$(stat -Lc '%a' "$gitconfig_file" 2>/dev/null || echo 600)"
		# git は "\tpath = <value>" の形で書くため、行頭の空白を落として完全一致で消す
		# （前方一致にすると gitconfig-host-foo のような別の値まで消えてしまう）。
		# mv の宛先は readlink -f で実体にする: ~/.gitconfig が symlink の場合に
		# symlink 自体を置き換えてリンクを壊さないため。
		if awk -v target="path = ${gitconfig_host}" '
			{ line = $0; sub(/^[ \t]+/, "", line); if (line == target) next; print }
		' "$gitconfig_file" >"$gitconfig_tmp" \
			&& chmod "$gitconfig_mode" "$gitconfig_tmp" \
			&& mv "$gitconfig_tmp" "$(readlink -f -- "$gitconfig_file")"; then
			echo "✓ 読めない include.path を ~/.gitconfig から取り除きました（残すと git が使えなくなるため）" >&2
		else
			rm -f "$gitconfig_tmp"
			echo "   ~/.gitconfig から include.path を取り除けませんでした。手動で削除してください" >&2
		fi
	fi
	# ここで続行すると、ホストの user.name / user.email が無いまま成功扱いになり、
	# 後で commit 時に "Author identity unknown" として表面化する。
	# mount が壊れている以上コンテナを作り直す必要があるので、明示的に失敗させる。
	# （壊れた include は上で取り除いてあるので、調査のために git は使える状態で残る）
	echo "✗ ${gitconfig_host} が読めないため、ホストの git config を取り込めません" >&2
	echo "  ホスト側で mise bootstrap dotfiles apply を実行し、devcontainer を作り直してください" >&2
	exit 1
fi
# host config の core.excludesfile（~/.config/git/gitignore）はコンテナ内に無いため、mount した実体へ向ける。
# 無視されないと、bind mount した .venv 等が未追跡に見えて pre-commit の stash -u が失敗する。
git config --global core.excludesfile ~/.config/gitignore-host
git config --global credential.https://github.com.helper '!gh auth git-credential'
git config --global url.https://github.com/.insteadOf git@github.com:
# コンテナには自分の worktree と common git dir しか mount しないため、同じリポジトリの
# 他の worktree はコンテナから見えない。git gc の自動 prune がそれらを「消えた worktree」と
# みなして .git/worktrees/<name> を削除し、ホスト側の worktree を壊さないようにする。
git config --global gc.worktreePruneExpire never

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

# identity が解決できているか確認する。ホストの gitconfig が空・未マウントだと
# include しても user.name / user.email が得られず、commit が "Author identity unknown" で失敗する。
if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
	echo "⚠️ git の user.name / user.email が解決できません。ホストの ~/.config/git/config（コンテナ内: ${gitconfig_host}）に [user] があるか確認してください" >&2
fi

# OS 依存の生成物を、ホストへ書き込まないコンテナローカル領域へ切り替える。
# 失敗を握りつぶさない。分離できないまま後続の依存インストールやビルドが走ると、
# .venv / node_modules / target がホスト共有のワークスペースへ書き込まれるため、作成時点で止める。
# （post-start.sh の再 mount は既存内容を隠すだけなので、そちらは警告して続行する。）
# git の identity 設定は上で済んでいるため、ここで止まっても commit はできる。
bash /home/vscode/.config/devcontainer/scripts/mount-container-only-dirs.sh "${PWD}"

# devcontainer専用のLefthook設定を各リポジトリへ配置し、hookをインストールする。
# multi-worktreeではworkspace(task root)自体がccmanager用のsynthetic git repositoryで、
# 実際のリポジトリは直下に並ぶ（例: task-root/repo-a, task-root/repo-b）。
# task rootのブランチ名でmulti-worktreeを判定し、その場合だけ直下のリポジトリを対象にする。
# 通常のリポジトリは直下にsubmoduleがあってもworkspace自体を対象にする。
lefthook_template="${HOME}/.config/devcontainer/lefthook.local.yml"

# 呼び出し元が `if ! install_lefthook ...` で失敗を警告に落とすため、bash の仕様上この関数内では
# set -e が効かない。各コマンドの失敗を確実に伝えるよう、明示的に `|| return 1` を付ける。
install_lefthook() {
	local repo_root=$1
	local local_lefthook_config="${repo_root}/lefthook.local.yml"
	if [ ! -e "$local_lefthook_config" ]; then
		cp "$lefthook_template" "$local_lefthook_config" || return 1
	fi
	local git_exclude
	git_exclude="$(git -C "$repo_root" rev-parse --path-format=absolute --git-path info/exclude)" || return 1
	mkdir -p "$(dirname "$git_exclude")" || return 1
	if ! grep -Fxq "lefthook.local.yml" "$git_exclude" 2>/dev/null; then
		echo "lefthook.local.yml" >>"$git_exclude" || return 1
	fi
	(
		cd "$repo_root" || exit 1
		LEFTHOOK_CONFIG="$local_lefthook_config" lefthook install
	) || return 1
	echo "✓ ${repo_root} に Lefthook をインストールしました"
}

lefthook_repo_roots=()
workspace_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
workspace_branch=""
if [ -n "$workspace_root" ]; then
	workspace_branch="$(git -C "$workspace_root" branch --show-current 2>/dev/null || true)"
fi
if [[ "$workspace_branch" == multi-worktree-* ]]; then
	for child_git in "${PWD}"/*/.git; do
		[ -e "$child_git" ] || continue
		child_root="$(dirname "$child_git")"
		git -C "$child_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
		lefthook_repo_roots+=("$child_root")
	done
elif [ -n "$workspace_root" ]; then
	lefthook_repo_roots+=("$workspace_root")
fi
for repo_root in "${lefthook_repo_roots[@]}"; do
	if ! install_lefthook "$repo_root"; then
		echo "⚠️ ${repo_root} への Lefthook のインストールに失敗しましたが、残りの作成処理を続行します" >&2
	fi
done

# .claude.json のコピー（既存の処理）
claude_config_host=~/.config/claude-config-host.json
if [ ! -f ~/.claude.json ] && [ -f "$claude_config_host" ]; then
	cp "$claude_config_host" ~/.claude.json
	echo "✓ .claude.json をコピーしました"
else
	echo "ℹ️ .claude.json のコピーはスキップしました"
fi

# claude-account2 / claude-work3 ディレクトリを作成し、~/.claude の設定を共有する
for account in claude-account2 claude-work3; do
	account_dir="${HOME}/.${account}"
	mkdir -p "${account_dir}"
	for shared_entry in projects settings.json agents skills plugins; do
		if [ ! -e "${account_dir}/${shared_entry}" ] && [ ! -L "${account_dir}/${shared_entry}" ] && [ -e "${HOME}/.claude/${shared_entry}" ]; then
			ln -s "../.claude/${shared_entry}" "${account_dir}/${shared_entry}"
			echo "✓ .${account}/${shared_entry} を共有しました"
		else
			echo "ℹ️ .${account}/${shared_entry} の共有はスキップしました"
		fi
	done
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
