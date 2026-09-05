#!/bin/bash
set -euo pipefail

workspace=${1:?workspace path is required}
storage_root=/var/lib/devcontainer-project-artifacts
declare -A targets=()

add_target() {
	local target=$1
	case "${target}" in
	"${workspace}"/*) targets["${target}"]=1 ;;
	*) echo "error: mount target is outside workspace: ${target}" >&2; exit 1 ;;
	esac
}

# 既に存在する対象ディレクトリは、深さを問わず検出する。
while IFS= read -r -d '' directory; do
	add_target "${directory}"
done < <(
	find "${workspace}" -xdev \
		\( -name .git -type d -prune \) -o \
		\( -type d \( -name node_modules -o -name .venv -o -name .gradle -o -name .terraform \) -print0 -prune \)
)

# まだ生成物ディレクトリがない場合も、プロジェクト定義から mount point を先に作る。
while IFS= read -r -d '' manifest; do
	directory=$(dirname "${manifest}")
	case "$(basename "${manifest}")" in
	package.json) add_target "${directory}/node_modules" ;;
	pyproject.toml | setup.py | setup.cfg | requirements.txt) add_target "${directory}/.venv" ;;
	Cargo.toml | pom.xml) add_target "${directory}/target" ;;
	build.gradle | build.gradle.kts | settings.gradle | settings.gradle.kts) add_target "${directory}/.gradle" ;;
	*.tf) add_target "${directory}/.terraform" ;;
	esac
done < <(
	find "${workspace}" -xdev \
		\( -name .git -o -name node_modules -o -name .venv -o -name target -o -name .gradle -o -name .terraform \) -type d -prune -o \
		-type f \( -name package.json -o -name pyproject.toml -o -name setup.py -o -name setup.cfg \
		-o -name requirements.txt -o -name Cargo.toml -o -name pom.xml -o -name build.gradle \
		-o -name build.gradle.kts -o -name settings.gradle -o -name settings.gradle.kts -o -name '*.tf' \) -print0
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
