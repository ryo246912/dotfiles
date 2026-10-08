#!/bin/bash
set -euo pipefail

workspace=${1:?workspace path is required}
storage_root=/var/lib/devcontainer-project-artifacts
declare -A targets=()

# ディレクトリ名だけで生成物と判断できるもの。
# target は一般用途でも使われるため、manifest_rules 経由でのみ対象にする。
artifact_directory_names=(node_modules .venv .gradle .terraform)

# "manifest のパターン:生成物ディレクトリ" の対応表。
manifest_rules=(
	"package.json:node_modules"
	"pyproject.toml:.venv"
	"setup.py:.venv"
	"setup.cfg:.venv"
	"requirements*.txt:.venv"
	"Cargo.toml:target"
	"pom.xml:target"
	"build.gradle:.gradle"
	"build.gradle.kts:.gradle"
	"settings.gradle:.gradle"
	"settings.gradle.kts:.gradle"
	"*.tf:.terraform"
)

append_name_predicates() {
	local -n predicates=$1
	shift
	local name
	for name in "$@"; do
		((${#predicates[@]} > 0)) && predicates+=(-o)
		predicates+=(-name "${name}")
	done
}

artifact_name_predicates=()
append_name_predicates artifact_name_predicates "${artifact_directory_names[@]}"

manifest_name_patterns=()
artifact_prune_names=("${artifact_directory_names[@]}")
for rule in "${manifest_rules[@]}"; do
	manifest_name_patterns+=("${rule%%:*}")
	artifact_prune_names+=("${rule#*:}")
done

manifest_name_predicates=()
append_name_predicates manifest_name_predicates "${manifest_name_patterns[@]}"

artifact_prune_predicates=()
append_name_predicates artifact_prune_predicates "${artifact_prune_names[@]}"

add_target() {
	local target=$1
	case "${target}" in
	"${workspace}"/*) targets["${target}"]=1 ;;
	*)
		echo "error: mount target is outside workspace: ${target}" >&2
		exit 1
		;;
	esac
}

# 既に存在する対象ディレクトリは、深さを問わず検出する。
while IFS= read -r -d '' directory; do
	add_target "${directory}"
done < <(
	find "${workspace}" -xdev \
		\( -name .git -type d -prune \) -o \
		\( -type d \( "${artifact_name_predicates[@]}" \) -print0 -prune \)
)

# まだ生成物ディレクトリがない場合も、プロジェクト定義から mount point を先に作る。
while IFS= read -r -d '' manifest; do
	directory=$(dirname "${manifest}")
	manifest_name=$(basename "${manifest}")
	for rule in "${manifest_rules[@]}"; do
		pattern=${rule%%:*}
		artifact_directory=${rule#*:}
		if [[ ${manifest_name} == ${pattern} ]]; then
			add_target "${directory}/${artifact_directory}"
			break
		fi
	done
done < <(
	find "${workspace}" -xdev \
		\( -name .git -o \( "${artifact_prune_predicates[@]}" \) \) -type d -prune -o \
		-type f \( "${manifest_name_predicates[@]}" \) -print0
)

# root で target を辿れない共有 FS 向けのフォールバック付き bind mount。
# Docker Sandboxes の workspace（virtiofs passthrough）はホスト側でアクセスを判定しており、
# agent ユーザーとしては読み書きできるが、root（sudo）からの要求は拒否されて
# `mount: ...: permission denied` になる（/proc/<pid>/fd 経由で渡しても同じだった）。
# そこで「uid/gid は実行ユーザーのまま、CAP_SYS_ADMIN だけ持たせて」mount(2) を呼ぶ。
# path の解決は実行ユーザーとして行われ、mount 自体は CAP_SYS_ADMIN で許可される。
# mount(8) は実 uid が root でないと fstab 以外を拒否する（restricted mode）ため、
# syscall は python3 から直接呼ぶ（4096 = MS_BIND）。
bind_mount_as_user() {
	command -v setpriv >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || return 1
	sudo setpriv --reuid="$(id -u)" --regid="$(id -g)" --groups="$(id -G | tr ' ' ,)" \
		--inh-caps=+sys_admin --ambient-caps=+sys_admin \
		python3 -I -c '
import ctypes, os, sys
libc = ctypes.CDLL(None, use_errno=True)
if libc.mount(sys.argv[1].encode(), sys.argv[2].encode(), None, 4096, None) != 0:
    sys.exit("mount: %s: %s" % (sys.argv[2], os.strerror(ctypes.get_errno())))
' "$1" "$2"
}

bind_mount() {
	local source=$1 target=$2 err
	err=$(sudo mount --bind "${source}" "${target}" 2>&1) && return 0
	if bind_mount_as_user "${source}" "${target}" 2>/dev/null && mountpoint -q "${target}"; then
		return 0
	fi
	echo "${err}" >&2
	return 1
}

sudo install -d -o "$(id -u)" -g "$(id -g)" "${storage_root}"
skipped=0
failed=0
for target in "${!targets[@]}"; do
	# シンボリックリンクは sudo の操作がリンク先（workspace 外のこともある）に及ぶため分離しない。
	if [ -L "${target}" ]; then
		echo "⚠️ シンボリックリンクのため分離しません: ${target}" >&2
		skipped=$((skipped + 1))
		continue
	fi
	mountpoint -q "${target}" && continue
	key=$(printf '%s' "${target}" | sha256sum | cut -d ' ' -f 1)
	backing_dir="${storage_root}/${key}"
	if [ -d "${target}" ] && [ -n "$(find "${target}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
		echo "ℹ️ ホスト側の既存内容を移行せず隠します: ${target}" >&2
	fi
	# 既存の target は mount で隠すだけなので、所有者・権限を変えないよう無いときだけ作る。
	# workspace は実行ユーザーが書けるので sudo は不要（sandbox では root だと辿れないこともある）。
	if [ ! -d "${target}" ]; then
		mkdir -p "${target}" || sudo install -d -o "$(id -u)" -g "$(id -g)" "${target}"
	fi
	sudo install -d -o "$(id -u)" -g "$(id -g)" "${backing_dir}"
	# 1 つ失敗しても残りは分離する（set -e で途中終了すると後続が全部ホストに書かれる）
	if ! bind_mount "${backing_dir}" "${target}"; then
		echo "⚠️ 分離できませんでした: ${target}" >&2
		failed=$((failed + 1))
	fi
done

echo "✓ $((${#targets[@]} - skipped - failed)) 個のプロジェクト生成物をコンテナ内に分離しました"
[ "${failed}" -eq 0 ]
