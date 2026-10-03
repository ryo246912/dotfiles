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

sudo install -d -o "$(id -u)" -g "$(id -g)" "${storage_root}"
for target in "${!targets[@]}"; do
	mountpoint -q "${target}" && continue
	key=$(printf '%s' "${target}" | sha256sum | cut -d ' ' -f 1)
	backing_dir="${storage_root}/${key}"
	if [ -d "${target}" ] && [ -n "$(find "${target}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
		echo "ℹ️ ホスト側の既存内容を移行せず隠します: ${target}" >&2
	fi
	sudo install -d -o "$(id -u)" -g "$(id -g)" "${target}" "${backing_dir}"
	sudo mount --bind "${backing_dir}" "${target}"
done

echo "✓ ${#targets[@]} 個のプロジェクト生成物をコンテナ内に分離しました"
