#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rulesync_dir="${repo_root}/dot_config/rulesync"
rulesync_bin="${RULESYNC_BIN:-rulesync}"
tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/rulesync-home.XXXXXX")"

cleanup() {
	rm -rf "${tmp_home}"
}
trap cleanup EXIT

build_trusted_paths() {
	local paths=("${repo_root}/mise.toml")
	while IFS= read -r path; do
		paths+=("${path}")
	done < <(find "${repo_root}/dot_config/mise" -maxdepth 1 -name '*.toml' -type f | sort)
	(
		IFS=:
		printf '%s' "${paths[*]}"
	)
}

sync_dir() {
	local src="$1"
	local dest="$2"

	if [ -d "${src}" ]; then
		rm -rf "${dest}"
		mkdir -p "$(dirname "${dest}")"
		cp -R "${src}" "${dest}"
	else
		rm -rf "${dest}"
	fi
}

sync_file() {
	local src="$1"
	local dest="$2"

	if [ -f "${src}" ]; then
		mkdir -p "$(dirname "${dest}")"
		cp "${src}" "${dest}"
	else
		rm -f "${dest}"
	fi
}

export MISE_TRUSTED_CONFIG_PATHS="${MISE_TRUSTED_CONFIG_PATHS:-$(build_trusted_paths)}"

(
	cd "${rulesync_dir}"
	"${rulesync_bin}" install --config rulesync.jsonc
	HOME="${tmp_home}" "${rulesync_bin}" generate \
		--config rulesync.jsonc \
		--global \
		--simulate-commands \
		--simulate-skills
)

sync_file "${tmp_home}/.claude/CLAUDE.md" "${repo_root}/dot_claude/CLAUDE.md"
sync_dir "${tmp_home}/.claude/skills" "${repo_root}/dot_claude/skills"
sync_dir "${tmp_home}/.claude/commands" "${repo_root}/dot_claude/commands"

sync_file "${tmp_home}/.codex/AGENTS.md" "${repo_root}/dot_codex/AGENTS.md"
sync_dir "${tmp_home}/.codex/skills" "${repo_root}/dot_codex/skills"
sync_dir "${tmp_home}/.codex/prompts" "${repo_root}/dot_codex/prompts"

sync_file "${tmp_home}/.gemini/GEMINI.md" "${repo_root}/dot_gemini/GEMINI.md"
sync_dir "${tmp_home}/.gemini/skills" "${repo_root}/dot_gemini/skills"
sync_dir "${tmp_home}/.gemini/commands" "${repo_root}/dot_gemini/commands"

sync_file "${tmp_home}/.copilot/copilot-instructions.md" "${repo_root}/dot_copilot/copilot-instructions.md"
