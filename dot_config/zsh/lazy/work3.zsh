[[ "${HOST_ENV:-}" == *work3* ]] || return

# ccmanager
if command -v ccmanager >/dev/null 2>&1; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/Programming/work3/worktrees
fi
