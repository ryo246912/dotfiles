[[ "${HOST_ENV:-}" == *work3* ]] || return

# ccmanager
# work.zsh (全workロール共通) の ~/work/worktrees をwork3ロールだけ上書きする。
# ファイル名のアルファベット順（lazy.zsh）でwork.zshの後にsourceされるため上書きが効く。
if command -v ccmanager >/dev/null 2>&1; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/Programming/work3/worktrees
fi
