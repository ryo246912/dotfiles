eval "$(mise activate zsh)"

# 補完ファイル生成用のディレクトリ
MISE_COMPLETIONS_DIR="$HOME/.cache/mise/completions"
mkdir -p "$MISE_COMPLETIONS_DIR"

# 補完ファイル生成とロードの関数
__generate_and_load_completion() {
    local tool="$1"
    local completion_file="$MISE_COMPLETIONS_DIR/_${tool}"

    case "$tool" in
        "atuin")
            atuin gen-completions --shell zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "gh")
            gh completion -s zsh > "$completion_file" 2>/dev/null
            fpath=("$MISE_COMPLETIONS_DIR" $fpath)
            ;;
        "mise")
            mise completion zsh > "$completion_file" 2>/dev/null
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

# mise
if command -v mise >/dev/null 2>&1; then
    __generate_and_load_completion "mise"
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
