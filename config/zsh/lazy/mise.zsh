eval "$(mise activate zsh)"

# `mise activate zsh` が生成したshell/deactivate対応functionを保持し、その外側で
# install/lock後のlockfile同期を行う。直接`command mise`を呼ぶとactivate固有処理が失われる。
functions[_mise_activated]="$functions[mise]"
mise() {
    # activateが生成したfunctionへ全引数をそのまま渡し、shell/deactivateを含む
    # mise本来の挙動を維持する。成功後は毎回lockfileの差分だけを確認することで、
    # 増減するglobal optionやinstall aliasを独自に解析せず保守できるようにする。
    _mise_activated "$@"
    local exit_status=$?
    (( exit_status == 0 )) && _sync_mise_dotfile_locks
    return $exit_status
}

# 補完ファイル生成用のディレクトリ
MISE_COMPLETIONS_DIR="$HOME/.cache/mise/completions"
mkdir -p "$MISE_COMPLETIONS_DIR"

# 補完ファイル生成とロードの関数
__generate_and_load_completion() {
    local tool="$1"
    local completion_file="$MISE_COMPLETIONS_DIR/_${tool}"

    case "$tool" in
        "atuin")
            [ ! -f "$completion_file" ] && atuin gen-completions --shell zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "aws-vault")
            curl -fs https://raw.githubusercontent.com/byteness/aws-vault/master/contrib/completions/zsh/aws-vault.zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "gh")
            [ ! -f "$completion_file" ] && gh completion -s zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "wt")
            [ ! -f "$completion_file" ] && wt completion zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "gwq")
            [ ! -f "$completion_file" ] && gwq completion zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "mise")
            [ ! -f "$completion_file" ] && mise completion zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "taws")
            taws completion zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
    esac
}

# atuin
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
    export ATUIN_CONFIG_DIR="$HOME/.config/atuin"
    __generate_and_load_completion "atuin"
fi

# aws-vault
if command -v aws-vault >/dev/null 2>&1; then
    __generate_and_load_completion "aws-vault"
fi

# aqua
if command -v aqua >/dev/null 2>&1; then
    export AQUA_GLOBAL_CONFIG="$HOME/.config/aqua/aqua.yaml"
fi

# bat
if command -v bat >/dev/null 2>&1; then
    export BAT_THEME="Monokai Extended"
    __generate_and_load_completion "bat"
fi

# delta
if command -v delta >/dev/null 2>&1; then
    compdef _gnu_generic delta
fi

# fnox
if command -v fnox >/dev/null 2>&1; then
    # BWS_ACCESS_TOKEN は bws provider 自体が要求する bootstrap 値なので、fnox activate より前に
    # 手動で export する。fnox set --global --provider age BWS_ACCESS_TOKEN で未設定のうちは
    # `fnox get` が失敗するだけで、shell 起動自体は落とさない。
    if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
        BWS_ACCESS_TOKEN="$(fnox get BWS_ACCESS_TOKEN 2>/dev/null)"
        [ -n "$BWS_ACCESS_TOKEN" ] && export BWS_ACCESS_TOKEN
    fi
    eval "$(fnox activate zsh)"
fi

# fzf
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='find $PWD -type d -path "$PWD/.*" -prune -o -not -name ".*" -type f -name "*" -print'
    if [ "$(uname)" = "Darwin" ]; then
        export FZF_DEFAULT_OPTS='-m --height 40% --layout=reverse --border --bind ctrl-k:kill-line,alt-right:forward-word,alt-left:backward-word'
    else
        export FZF_DEFAULT_OPTS='-m --height 40% --layout=reverse --border'
        bindkey "^[R" fzf-history-widget # alt + shift + r
        bindkey -r "^R"
    fi
fi

# GitHub CLI
if command -v gh >/dev/null 2>&1; then
    __generate_and_load_completion "gh"
fi

# worktrunk
if command -v wt >/dev/null 2>&1; then
    eval "$(wt config shell init zsh)"
    __generate_and_load_completion "wt"
fi

# gwq
if command -v gwq >/dev/null 2>&1; then
    __generate_and_load_completion "gwq"
    source "$MISE_COMPLETIONS_DIR/_gwq"
fi

# mise
if command -v mise >/dev/null 2>&1; then
    __generate_and_load_completion "mise"
fi

# taws
if command -v taws >/dev/null 2>&1; then
    __generate_and_load_completion "taws"
fi

# zabrze
if command -v zabrze >/dev/null 2>&1; then
    eval "$(zabrze init --bind-keys)"
fi

# zoxide
if command -v zoxide >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/state/zoxide" 2>/dev/null
    export _ZO_DATA_DIR="$HOME/.local/state/zoxide"
    eval "$(zoxide init zsh --cmd j)"
fi
