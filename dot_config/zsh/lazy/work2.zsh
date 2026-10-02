[[ "${HOST_ENV:-}" == *work2* ]] || return

# ccmanager
if command -v ccmanager >/dev/null 2>&1; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/work/worktrees
fi
