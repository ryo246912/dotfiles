#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_ROOT="${TMPDIR:-/tmp}/multi-worktree-smoke-cache"
export GOCACHE="${CACHE_ROOT}/build"
export GOPATH="${CACHE_ROOT}/path"
export GOMODCACHE="${CACHE_ROOT}/mod"
mkdir -p "${GOCACHE}" "${GOPATH}" "${GOMODCACHE}"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/multi-worktree-smoke.XXXXXX")"
trap 'chmod -R u+w "${WORK_DIR}" 2>/dev/null || true; rm -rf "${WORK_DIR}"' EXIT

SOURCE_REPOS="${WORK_DIR}/repos"
CONFIG_HOME="${WORK_DIR}/config"
HOME_DIR="${WORK_DIR}/home"
mkdir -p "${SOURCE_REPOS}" "${CONFIG_HOME}/multi-worktree" "${HOME_DIR}/.config/devcontainer"

create_repo() {
  local name="$1"
  local repo_dir="${SOURCE_REPOS}/${name}"

  mkdir -p "${repo_dir}"
  git -C "${repo_dir}" init -b main >/dev/null
  git -C "${repo_dir}" config user.name "multi-worktree-test"
  git -C "${repo_dir}" config user.email "multi-worktree-test@example.com"
  printf '%s\n' "${name}" > "${repo_dir}/README.md"
  git -C "${repo_dir}" add README.md
  git -C "${repo_dir}" commit -m "init" >/dev/null
  git -C "${repo_dir}" branch develop >/dev/null
}

create_repo "repo-a"
create_repo "repo-b"

cat > "${CONFIG_HOME}/multi-worktree/config.toml" <<EOF
[groups.default]
repos = [
  "${SOURCE_REPOS}/repo-a",
  "${SOURCE_REPOS}/repo-b",
]
base_dir = "../worktrees"
worktree_prefix = "multi-worktree"

[settings]
default_group = "default"

[settings.devcontainer]
skip_up_if_running = true

[dev_commands]
test = "echo smoke"
EOF

cat > "${HOME_DIR}/.config/devcontainer/devcontainer.json" <<'EOF'
{
  "name": "Base",
  "mounts": []
}
EOF

run_cli() {
  (
    cd "${ROOT_DIR}"
    env -i \
      PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      HOME="${HOME_DIR}" \
      XDG_CONFIG_HOME="${CONFIG_HOME}" \
      TMPDIR="${TMPDIR:-/tmp}" \
      GOCACHE="${GOCACHE}" \
      GOPATH="${GOPATH}" \
      GOMODCACHE="${GOMODCACHE}" \
      go run ./cmd/multi-worktree "$@"
  )
}

run_cli create feat/smoke --default-branch
run_cli list | grep -q 'feat/smoke'
run_cli status feat/smoke >/dev/null
run_cli sync feat/smoke repo-a >/dev/null
rm -rf "${WORK_DIR}/worktrees/multi-worktree-feat-smoke/repo-b"
run_cli recreate feat/smoke --default-branch >/dev/null
printf 'y\n' | run_cli remove feat/smoke >/dev/null

if [[ -d "${WORK_DIR}/worktrees/multi-worktree-feat-smoke" ]]; then
  echo "worktree directory still exists" >&2
  exit 1
fi
