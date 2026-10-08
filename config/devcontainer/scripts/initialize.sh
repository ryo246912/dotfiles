#!/bin/bash
set -e

# devcontainer.json の initializeCommand としてホスト側で実行されるスクリプト。
#
# devcontainer.json の `mounts` は `docker run --mount` で処理されるため、レガシーな `-v` と
# 違って source パスが存在しないとコンテナ作成自体が失敗する（target 側は常にコンテナ内で
# 新規に作られるので問題にならない）。initializeCommand はコンテナ作成前にホスト側で実行される
# ため、ここで mounts の source を全て事前に用意しておくことでその失敗を防ぐ。
#
# 注意: devcontainer.json の mounts を変更したら、このスクリプトも合わせて更新すること。

ensure_dir() {
	[ -e "$1" ] || {
		mkdir -p "$1"
		echo "✓ 作成(ディレクトリ): $1"
	}
}

ensure_empty_file() {
	[ -e "$1" ] || {
		mkdir -p "$(dirname "$1")"
		touch "$1"
		echo "✓ 作成(空ファイル): $1"
	}
}

ensure_json_file() {
	[ -e "$1" ] || {
		mkdir -p "$(dirname "$1")"
		echo '{}' >"$1"
		echo "✓ 作成(空JSON): $1"
	}
}

# 自分の PID を書き込んだ「宣言用」ディレクトリを一時パスに用意してから、それを
# mv で $lock へ公開する。mkdir してから別途 pid を書き込む(2手順に分かれた)
# 従来方式だと、mkdir 成功後にスケジューリング等で長時間止まった場合、その間に
# 他プロセスがこのロックを「pid が無いままの孤児」とみなして奪ってしまい、後から
# 目覚めた自分が pid を書き込むと今度は相手の(新しい)ロックを上書きしてしまう、
# という競合があった。pid を書いた状態のディレクトリを一括で公開すれば、$lock が
# 存在する瞬間には必ず正しい pid が入っており、この隙間が生まれない。
#
# mv の宛先が既に(別プロセスの)ディレクトリとして存在する場合、mv は「その中へ
# 移動」するだけで置き換えてくれないため、公開後に ${lock}/pid を読み直して本当に
# 自分の PID になっているか確認する。なっていなければ自分の宣言用ディレクトリが
# 誤って相手のロックの中へネストされているので、それを片付けてから諦める
# (呼び出し元はループを継続し、次の機会に取り直す)。
_ssh_key_lock_publish() {
	local lock="$1" tmp
	tmp="${lock}.claim.$$"
	rm -rf "$tmp" 2>/dev/null
	mkdir "$tmp" 2>/dev/null || return 1
	if ! echo "$$" >"${tmp}/pid" 2>/dev/null; then
		rm -rf "$tmp" 2>/dev/null
		return 1
	fi
	if ! mv "$tmp" "$lock" 2>/dev/null; then
		rm -rf "$tmp" 2>/dev/null
		return 1
	fi
	if [ "$(cat "${lock}/pid" 2>/dev/null || true)" = "$$" ]; then
		return 0
	fi
	rm -rf "${lock}/$(basename "$tmp")" 2>/dev/null
	return 1
}

# ロックの中身を自分専用の名前へ mv で原子的に退避し、実際に死んでいた(あるいは
# pid ファイルが無かった)場合だけ破棄する。退避した中身が実は生きていた場合
# (競合)は、$lock が空いていれば元に戻す。呼び出し元はこの後どのみちループを
# 継続すればよい(奪取できていれば次の _ssh_key_lock_publish で自分が取得できる)。
#
# 「死んでいる/孤児だと判断してから rm -rf する」のように確認と削除の間に隙間が
# あると、その隙間で別プロセスが同じロックを正当に奪って再取得していた場合、その
# 生きているロックごと消してしまう(TOCTOU)。rm ではなく mv で退避してから改めて
# 中身を検査することでこれを避ける。
_ssh_key_lock_try_steal() {
	local lock="$1" stolen pid
	stolen="${lock}.stale.$$"
	if mv "$lock" "$stolen" 2>/dev/null; then
		pid="$(cat "${stolen}/pid" 2>/dev/null || true)"
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			if [ ! -e "$lock" ]; then
				mv "$stolen" "$lock" 2>/dev/null || rm -rf "$stolen" 2>/dev/null
			else
				rm -rf "$stolen" 2>/dev/null
			fi
		else
			rm -rf "$stolen" 2>/dev/null
		fi
	fi
}

# 鍵パスへのロックを取得する。50回(最大5秒)試して取れなければ諦める。
# ロックディレクトリには取得者の PID を書き込み、取得できなかった場合はその PID がまだ
# 生きているか確認する: 既に死んでいれば(クラッシュ等で残った古いロック)奪って取り直す。
# 生きていれば、鍵ファイルを同時に触ると壊れるため、諦めて呼び出し元にエラーを返す
# (鍵の書き換えを試みるより、その回の処理をスキップする方が安全)。
#
# mkdir 成功後・pid 書き込み前にプロセスが死ぬと、pid ファイルの無いロックが孤児として
# 残る。これは「pid が無い = 死んでいる」と即断せず(mkdir 直後の一瞬はまだ書き込み中の
# 可能性があるため)、pid ファイルが無い状態が何回か(0.5秒相当)続いて初めて孤児と
# みなして奪取する。放置すると誰も永久に取得できなくなるため、これも必ず処理する。
_ssh_key_lock_acquire() {
	local lock="$1" i pid no_pid_streak=0
	for i in $(seq 1 50); do
		if _ssh_key_lock_publish "$lock"; then
			return 0
		fi
		if [ -f "${lock}/pid" ]; then
			no_pid_streak=0
			pid="$(cat "${lock}/pid" 2>/dev/null || true)"
			if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
				_ssh_key_lock_try_steal "$lock"
				continue
			fi
		else
			no_pid_streak=$((no_pid_streak + 1))
			if [ "$no_pid_streak" -ge 5 ]; then
				_ssh_key_lock_try_steal "$lock"
				no_pid_streak=0
				continue
			fi
		fi
		sleep 0.1
	done
	return 1
}

# ensure_ssh_key の本体(ロック取得後に呼ばれる)。
_ensure_ssh_key_locked() {
	local key="$1" comment="$2"
	if [ -f "$key" ]; then
		# 秘密鍵から公開鍵を導出して .pub と同期する。.pub が無い場合(削除・復元漏れ)だけでなく、
		# 秘密鍵だけ手動で差し替えられて .pub が古い(鍵ペアの不一致)場合も、常に導出し直して
		# 比較することでまとめて解消する。
		# `-P ""` でパスフレーズ入力を待たせず即エラーにする: initializeCommand は非対話実行のため、
		# 対話プロンプトが出るとコンテナ作成が無期限にハングしてしまう。
		local pub_tmp="${key}.pub.tmp.$$"
		if ! ssh-keygen -y -P "" -f "$key" >"$pub_tmp" 2>/dev/null; then
			rm -f "$pub_tmp"
			echo "✗ 秘密鍵からの公開鍵の導出に失敗しました(パスフレーズ付き秘密鍵は非対応): ${key}" >&2
			return 1
		fi
		if [ ! -f "${key}.pub" ] || ! cmp -s "$pub_tmp" "${key}.pub"; then
			mv "$pub_tmp" "${key}.pub"
			echo "✓ 秘密鍵から公開鍵を(再)構成しました: ${key}.pub"
		else
			rm -f "$pub_tmp"
		fi
		return 1
	fi
	mkdir -p "$(dirname "$key")"
	# 秘密鍵が無いのに孤立した .pub だけ残っていると、ssh-keygen が対話的な上書き確認で
	# 止まってしまうため、鍵ペア生成前に削除しておく。
	rm -f "${key}.pub"
	# この関数は `if ensure_ssh_key ...; then` や `... || rc=$?` のように呼び出し元で
	# 常にガードされているため、bash の仕様上 `set -e` はここでは効かない(ガードされた
	# コマンド内では無効になる)。そのため ssh-keygen の失敗を明示的に検査しないと、
	# 鍵ファイルが実際には存在しないのに "✓ 生成しました" と表示して 0 を返してしまう。
	# 既存鍵がある場合の 1(no-op)とは区別できる 2 を返し、呼び出し元(トップレベル)で
	# 明示的にスクリプト全体を止められるようにする。
	if ! ssh-keygen -t ed25519 -N "" -f "$key" -C "$comment" -q; then
		echo "✗ SSH鍵の生成に失敗しました: $key" >&2
		return 2
	fi
	echo "✓ SSH鍵を生成しました: $key"
	return 0
}

# 鍵ペアが無ければ生成する。新規に鍵ペアを生成した場合は 0、既存の鍵をそのまま使った場合(または
# ロック取得失敗などで処理をスキップした場合)は 1 を返す。
# multi-worktree 等で複数の devcontainer が同じ鍵パスへ同時に initializeCommand から触れる
# 可能性があるため、鍵の生成/同期処理を直列化する。
#
# `flock` が使えるならそちらを使う: プロセスが保持する fd に紐づく OS レベルの
# アドバイザリロックで、mkdir/pid ファイルベースの自前実装と違って TOCTOU が原理的に無く、
# プロセスが死ねば OS が自動的に解放するため孤児ロックも発生しない。WSL2/Linux では
# util-linux の一部として標準で入っていることが多い。
# `flock` が無い環境(素の macOS 等)向けには、`_ssh_key_lock_acquire` による
# mkdir ベースのフォールバックを用意している。こちらは死んだ/孤児ロックの回収を
# ベストエフォートで行うが、`flock` ほど厳密ではない(ごく狭い理論上の競合が残りうる)。
ensure_ssh_key() {
	# `local key=... lock="${key}.lock"` のように同じ local 文の中で書くと、右辺の ${key} は
	# この文で代入する新しい値ではなく代入前の(未設定の)値を参照してしまうため、
	# 必ず key を確定させた後に別の local 文で lock を組み立てる。
	local key="$1" comment="$2" rc=0
	local lock="${key}.lock"
	if command -v flock >/dev/null 2>&1; then
		(
			exec 9>"$lock"
			if ! flock -w 5 9; then
				echo "✗ ロック取得がタイムアウトしたため、鍵の処理をスキップしました: ${key}" >&2
				# 鍵がまだ無いままスキップすると mount source が欠けて devcontainer up が失敗するため、
				# その場合は回復不能(2)として呼び出し元で止める。
				[ -f "$key" ] || exit 2
				exit 1
			fi
			_ensure_ssh_key_locked "$key" "$comment"
		) || rc=$?
		return "$rc"
	fi
	if ! _ssh_key_lock_acquire "$lock"; then
		echo "✗ ロック取得がタイムアウトしたため、鍵の処理をスキップしました: ${key}" >&2
		[ -f "$key" ] || return 2
		return 1
	fi
	_ensure_ssh_key_locked "$key" "$comment" || rc=$?
	rm -rf "$lock" 2>/dev/null || true
	return "$rc"
}

# .config/* (gh・mise はツール側が初回実行時に作るディレクトリ。未実行だと無いことがある)
ensure_dir ~/.config/gh
ensure_dir ~/.config/mise
ensure_dir ~/.config/nvim

# mise の [dotfiles] は ~/.config を symlink-each で配置するため、配下のファイルは
# dotfiles リポジトリを指す symlink になっている。これをそのまま bind mount すると、
# リンク先のホストのパスはコンテナ内に無いためリンク切れになる。Docker の build context も
# コンテナ外を指す symlink を辿らないため COPY が "not found" で失敗する。
# そこで symlink を解決した実体のコピーをホスト側に作り、devcontainer.json はそちらを
# build context と read-only mount の source として参照する（元が read-only mount なので
# コピーでも挙動は変わらない）。コンテナ作成ごとにこの initializeCommand で差分反映するため、
# ~/.config 側の編集は次の起動で反映される。
#
# 置き場所は ~/.cache 配下に固定する: devcontainer.json では ${localEnv:...} に既定値を
# 書けないため、XDG_CACHE_HOME ではなく ~/.cache を直接使う必要がある。
HOST_CONFIG_STAGE="$HOME/.cache/devcontainer/host-config"

# 注意: ディレクトリごと rm -rf して作り直してはいけない。このコピーは起動中の
# devcontainer が bind mount しているため（multi-worktree では複数が同時に動く）、
# 新しいコンテナを作るたびに中身を消すと、動いているコンテナから設定が消える。
# そのため「一時ディレクトリへ実体をコピーしてから、差分だけを mv で反映」する。
#
# mv は同一ファイルシステム内では atomic（rename(2)）なので、起動中のコンテナが
# 中途半端な内容のファイルを読むことがない。dst へ直接 cp すると書き込み途中の
# 内容が見えてしまう。
materialize_config() {
	local name="$1" src dst tmp rel rc=0 stale dirs files
	src="$HOME/.config/$name"
	dst="${HOST_CONFIG_STAGE}/$name"
	if [ ! -d "$src" ]; then
		# 配置先から消えた場合、過去の実行で作ったコピーを残すと「消したはずの設定」が
		# 新しいコンテナへ mount され続ける。mount 元として存在だけ残し、中身を空にする。
		# 元から無いもの（未導入のツール等）は何もせず成功扱いにする。
		if [ -d "$dst" ]; then
			rm -rf "$dst"
			mkdir -p "$dst"
			echo "⚠️ ホスト側から消えたため staged コピーを空にしました: $src" >&2
			return 1
		fi
		return 0
	fi
	mkdir -p "$dst"
	tmp="${HOST_CONFIG_STAGE}/.staging-${name}"
	rm -rf "$tmp"
	mkdir -p "$tmp"

	# -L で symlink を辿って、まず一時ディレクトリへ実体をコピーする
	if ! cp -RL "$src/." "$tmp/" 2>/dev/null; then
		echo "⚠️ 一部をコピーできませんでした(リンク切れ?): $src" >&2
		rc=1
	fi

	# dst から消すもの: 配置先から消えた entry と、file ↔ directory で型が変わった entry。
	# 走査中に削除するため、先に一覧を確定させる。
	stale=$(cd "$dst" && find . -mindepth 1 2>/dev/null)
	printf '%s\n' "$stale" | while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		rel="${rel#./}"
		if [ ! -e "${tmp}/${rel}" ]; then
			rm -rf "${dst}/${rel}"
		elif [ -d "${tmp}/${rel}" ] && [ ! -d "${dst}/${rel}" ]; then
			rm -rf "${dst}/${rel}"
		elif [ ! -d "${tmp}/${rel}" ] && [ -d "${dst}/${rel}" ]; then
			rm -rf "${dst}/${rel}"
		fi
	done

	# ディレクトリを先に作り、ファイルは mv で atomic に置き換える
	dirs=$(cd "$tmp" && find . -mindepth 1 -type d 2>/dev/null)
	files=$(cd "$tmp" && find . ! -type d 2>/dev/null)
	printf '%s\n' "$dirs" | while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		mkdir -p "${dst}/${rel#./}"
	done
	printf '%s\n' "$files" | while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		rel="${rel#./}"
		mv -f "${tmp}/${rel}" "${dst}/${rel}"
	done

	rm -rf "$tmp"
	[ "$rc" -eq 0 ] && echo "✓ 実体化: $dst"
	return "$rc"
}

# ファイル単位の mount 元も同じように実体化する。
#
# 当初は「ファイル単位の bind mount なら Docker が source 側の symlink を解決するので
# そのままで良い」と考えていたが、実際には symlink がコンテナ内へそのまま渡り、
# core.excludesfile が指す ~/.config/gitignore-host が
# "Too many levels of symbolic links" で読めなくなる事例が出た。
# Docker の symlink 解決に依存せず、ここで実体を作って渡す。
#
# 実体化に失敗しても mount 元が欠けないように、空の実体を用意しておく
# （mounts の source が無いとコンテナ作成自体が失敗するため。このファイル冒頭の説明を参照）。
ensure_staged_placeholder() {
	local dst="$1" placeholder="$2"
	[ -e "$dst" ] && return 0
	mkdir -p "$(dirname "$dst")"
	if [ -n "$placeholder" ]; then
		printf '%s\n' "$placeholder" >"$dst"
	else
		: >"$dst"
	fi
	echo "✓ 作成(空の実体): $dst"
}

# 引数: <コピー先の名前> <コピー元のパス> [実体化できなかったときに書く内容]
materialize_file() {
	local name="$1" src="$2" placeholder="${3:-}" dst tmp
	dst="${HOST_CONFIG_STAGE}/files/${name}"
	mkdir -p "$(dirname "$dst")"
	# [ -e ] はリンク切れの symlink に対して偽になるので、リンク切れもここで弾ける
	if [ ! -e "$src" ]; then
		# 配置先から消えた・リンク切れになった場合、過去の実行で作ったコピーを残すと
		# 「消したはずの設定」が新しいコンテナへ mount され続ける。古いコピーは捨てる。
		rm -f "$dst"
		echo "⚠️ 実体化できません(未配置かリンク切れ): $src" >&2
		ensure_staged_placeholder "$dst" "$placeholder"
		return 1
	fi
	tmp="${dst}.new"
	# -L で symlink を辿って実体をコピーし、mv で atomic に置き換える
	if ! cp -L "$src" "$tmp" 2>/dev/null; then
		rm -f "$tmp"
		# source はあるのにコピーだけ失敗した場合は一時的な事象の可能性があるため、
		# 既存のコピーは消さずに残す（無い場合だけ空の実体を用意する）
		echo "⚠️ 実体化に失敗しました: $src" >&2
		ensure_staged_placeholder "$dst" "$placeholder"
		return 1
	fi
	mv -f "$tmp" "$dst"
	echo "✓ 実体化: $dst"
}

materialize_all() {
	# build context になる devcontainer は失敗を致命的に扱う（古いコピーのまま build させない）
	materialize_config devcontainer || return 1
	# 残りは read-only な設定の共有なので、1 つリンク切れがあっても起動は止めない
	materialize_config nvim || echo "⚠️ nvim 設定の実体化に失敗しました" >&2
	materialize_config mise || echo "⚠️ mise 設定の実体化に失敗しました" >&2

	# gitconfig / gitignore はコンテナ内の git が常に読むため、失敗を致命的に扱う。
	# ここが読めないと core.excludesfile の解決に失敗して git status 系が全部死ぬ。
	materialize_file gitconfig-host "$HOME/.config/git/config" || return 1
	materialize_file gitignore-host "$HOME/.config/git/gitignore" || return 1

	# agent の設定。無くても起動はできるので warning 止まりにする
	materialize_file claude-config-host.json "$HOME/.claude.json" '{}' \
		|| echo "⚠️ .claude.json の実体化に失敗しました" >&2
	materialize_file claude-settings.json "$HOME/.claude/settings.json" '{}' \
		|| echo "⚠️ .claude/settings.json の実体化に失敗しました" >&2
	materialize_file codex-config.toml "$HOME/.codex/config.toml" \
		|| echo "⚠️ .codex/config.toml の実体化に失敗しました" >&2
	materialize_file codex-hooks.json "$HOME/.codex/hooks.json" '{}' \
		|| echo "⚠️ .codex/hooks.json の実体化に失敗しました" >&2
	return 0
}

# 実体化は直列化する。multi-worktree で複数の devcontainer を同時に起動すると
# initializeCommand も同時に走り、同じコピーへ書き込んでしまう。
# ロックの仕組みは SSH 鍵の処理（_ssh_key_lock_acquire）と同じものを流用する。
with_stage_lock() {
	local lock="${HOST_CONFIG_STAGE}.lock" rc=0
	mkdir -p "$(dirname "$lock")"
	if command -v flock >/dev/null 2>&1; then
		(
			exec 9>"$lock"
			flock -w 60 9 || exit 3
			"$@"
		) || rc=$?
		[ "$rc" -eq 3 ] && echo "✗ 設定の実体化のロック取得がタイムアウトしました" >&2
		return "$rc"
	fi
	if ! _ssh_key_lock_acquire "$lock"; then
		echo "✗ 設定の実体化のロック取得がタイムアウトしました" >&2
		return 1
	fi
	"$@" || rc=$?
	rm -rf "$lock" 2>/dev/null || true
	return "$rc"
}

# .ssh
ensure_empty_file ~/.ssh/known_hosts
# devcontainer専用のSSH鍵（ホスト通知用。docs/devcontainer.md 参照）
# ensure_ssh_key の戻り値: 0=新規生成, 1=既存鍵のまま(no-op)/取得失敗等でスキップ,
# 2=新規鍵の生成自体が失敗、または鍵が無いままロック取得に失敗(回復不能。mount source が用意できないため続けても
# devcontainer up がどのみち失敗するので、ここで明示的に止める)。
notify_rc=0
ensure_ssh_key ~/.ssh/id_docker_devcontainer "devcontainer host notify" || notify_rc=$?
[ "$notify_rc" -eq 2 ] && exit 1
# devcontainer専用のSSH鍵（コミット署名用。docs/devcontainer.md 参照）
sign_rc=0
ensure_ssh_key ~/.ssh/id_docker_devcontainer_sign "devcontainer commit signing" || sign_rc=$?
[ "$sign_rc" -eq 2 ] && exit 1
if [ "$sign_rc" -eq 0 ]; then
	echo "  → GitHub Settings > SSH and GPG keys > New SSH key (Key type: Signing Key) に以下を登録してください:"
	cat ~/.ssh/id_docker_devcontainer_sign.pub
fi

# AI agent configs（初回セットアップ前でコンテナを起動できるよう、無ければ空の状態を用意する）
ensure_dir ~/.claude
ensure_json_file ~/.claude/settings.json
ensure_json_file ~/.claude.json
ensure_dir ~/.claude-account2
ensure_dir ~/.claude-work3
ensure_dir ~/.agents
ensure_dir ~/.codex
# ~/.codex 配下の設定は symlink-each で配置されるため、ディレクトリごとの mount では
# リンク切れになる。~/.claude/settings.json と同じく実体を単体 mount するので、
# dotfiles 未適用でも mount source が欠けないように用意しておく。
ensure_empty_file ~/.codex/config.toml
ensure_json_file ~/.codex/hooks.json
ensure_dir ~/.copilot
ensure_dir ~/.coderabbit

# .aws（config だけを mount する。AWS を使わないホストには無いため、無ければ空ファイルを用意する）
ensure_empty_file ~/.aws/config

# ---------------------------------------------------------------------------
# ホスト設定の実体化（symlink の解決）
# ---------------------------------------------------------------------------
# mount 元が全て揃ってから実行する必要があるため、ensure_* の後＝このファイルの最後に置く
# （~/.codex/config.toml などは上の ensure_* で初めて作られるので、先に実体化すると
# 「未配置」と判定してしまう）。
with_stage_lock materialize_all || exit 1

# build context と Dockerfile の COPY 対象が揃っているか確認する
# （dotfiles 未適用・リンク切れをここで検出し、分かりにくい docker build エラーを避ける）
stage_missing=""
for required in Dockerfile mise.toml tasks lint scripts lefthook.local.yml; do
	# 実体化コピーだけを見ると、過去の実行で作られた古いコピーが残っているせいで
	# 「配置先から消えた・リンク切れになった」のを見逃す。配置先と両方を確認する
	# （[ -e ] はリンク切れの symlink に対して偽になるのでリンク切れも検出できる）。
	[ -e "$HOME/.config/devcontainer/${required}" ] \
		&& [ -e "${HOST_CONFIG_STAGE}/devcontainer/${required}" ] \
		|| stage_missing="${stage_missing}${stage_missing:+, }${required}"
done
if [ -n "$stage_missing" ]; then
	echo "✗ devcontainer の build context に必要なものがありません: ${stage_missing}" >&2
	echo "  mise bootstrap dotfiles apply で ~/.config/devcontainer を配置してください" >&2
	exit 1
fi
