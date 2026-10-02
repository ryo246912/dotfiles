[[ "${HOST_ENV:-}" == *work3* ]] || return

# ccmanager
# work.zsh (全workロール共通) はwork3のときこの変数を設定しないため、ここが唯一の設定箇所になる。
if command -v ccmanager >/dev/null 2>&1 && [[ "${HOST_ENV:-}" == *work3* ]]; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/Programming/work3/worktrees
fi
