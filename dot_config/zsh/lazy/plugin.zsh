# cSpell:disable
# https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#ice-modifiers
# wait = 遅延読み込み wait"0"と同義
# lucid = プラグイン読込時の表示をOFF
# blockf = プラグインによる$pathの変更を禁止する
# light-mode = for構文におけるzinit light(light-modeがない場合はzinit snippet相当)
# as"program" = zshプラグインでないものを読込(ソースを$pathに追加)
# as"completion" = 補完プラグインとして追加
# from = clone先を指定 [from"github"(デフォルト)/from"gh-r"(Github Release)]
# bpick= gh-rするファイル名を指定 [例.bpick"nnn-v*"]
# mv = ファイルをmv
# cp = ファイルをcp
# atclone= clone後に実行する関数を指定
# atpull= pull後(upgrade)に実行する関数を指定 [atpull"%atclone" = atcloneの内容を実行]
# configure=./configureを実行、make前に実行の場合はconfigure'!'
# make= make install、インストール先を指定するにはmake PREFIX=$ZPFX
# rustup = rust installer
# cargo = rust builder and package manager
# (plugin script loading)
# src = 読込完了時に指定ファイル読込
# atload = 読込完了時に実行する関数を指定
# pick = 引数に与えられたものを$pathに追加
# sbin = 引数に与えられたものを$pathに追加

# 実行順:atinit -> atpull! -> make'!!' -> mv -> cp -> make! -> atclone/atpull -> make -> (plugin script loading) -> src -> multisrc -> atload.
# https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#order-of-execution

### command ###
# atuin #
__atuin_atload() {
    eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
    export ATUIN_CONFIG_DIR="$HOME/.config/atuin"
}
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v18.0.1" \
    sbin"atuin*/atuin" \
    atclone"atuin gen-completions --shell zsh > _atuin" atpull"%atclone" \
    atload"__atuin_atload" \
    @'atuinsh/atuin'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" bpick"*x86_64-unknown-linux-musl*" \
    ver"v18.0.1" \
    sbin"atuin*/atuin" \
    atclone"atuin gen-completions --shell zsh > _atuin" atpull"%atclone" \
    atload"__atuin_atload" \
    @'atuinsh/atuin'
fi

# bat #
__bat_atload() {
    export BAT_THEME="Monokai Extended"
}
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.23.0" \
    sbin"bat*/bat" \
    cp"bat*/autocomplete/bat.zsh -> _bat" \
    atload"__bat_atload" \
    @'sharkdp/bat'

# Clipboard #
zinit wait lucid light-mode blockf for \
    atclone"go build cmd/gocopy/gocopy.go && go build cmd/gopaste/gopaste.go" atpull"%atclone" \
    sbin"gocopy -> gocopy" \
    sbin"gopaste -> gopaste" \
    @'atotto/clipboard'

# delta #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"0.16.5" \
    sbin"delta*/delta" \
    atload"compdef _gnu_generic delta" \
    @'dandavison/delta'

# diffnav #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.2.8" \
    sbin"diffnav" \
    @'dlvhdr/diffnav'

# difftastic #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"0.54.0" \
    sbin"difft" \
    @'Wilfred/difftastic'

# fzf #
__fzf_atload() {
    export FZF_DEFAULT_COMMAND='find $PWD -type d -path "$PWD/.*" -prune -o -not -name ".*" -type f -name "*" -print'
    if [ "$(uname)" = "Darwin" ]; then
      export FZF_DEFAULT_OPTS='-m --height 40% --layout=reverse --border --bind ctrl-k:kill-line,alt-right:forward-word,alt-left:backward-word'
    else
      export FZF_DEFAULT_OPTS='-m --height 40% --layout=reverse --border'
      bindkey "^[R" fzf-history-widget # alt + shift + r
      bindkey -r "^R"
    fi
}
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.64.0" \
    sbin"fzf" \
    atload"__fzf_atload" \
    @'junegunn/fzf'
zinit wait lucid blockf for \
    "https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh" \
    "https://github.com/junegunn/fzf/blob/master/shell/completion.zsh"

# fx #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"30.1.0" \
    sbin"fx* -> fx" \
    @'antonmedv/fx'

# gitui #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.22.1" \
    sbin"gitui" \
    @'gitui-org/gitui'

# github-cli #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v2.55.0" \
    sbin"gh*/bin/gh" \
    atclone"./gh*/bin/gh completion -s zsh >_gh" atpull"%atclone" \
    @'cli/cli'

# git-who #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.7" \
    sbin"git-who" \
    @'sinclairtarget/git-who'

# gh-extension(gh-dash) #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v4.14.0" \
    sbin"*darwin* -> gh-dash" \
    @'dlvhdr/gh-dash'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v4.14.0" \
    sbin"*linux* -> gh-dash" \
    @'dlvhdr/gh-dash'
fi

# gh-extension(gh-poi) #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.10.1" \
    sbin"darwin* -> gh-poi" \
    @'seachicken/gh-poi'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.10.1" \
    sbin"linux* -> gh-poi" \
    @'seachicken/gh-poi'
fi

# jq #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"jq-1.6" \
    sbin"jq* -> jq" \
    @'jqlang/jq'

# lazydocker #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.23.1" \
    sbin"lazydocker* -> lazydocker" \
    @'jesseduffield/lazydocker'

# mise #
__mise_atload() {
    eval "$(mise activate zsh)"
}

if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v2024.12.24" \
    bpick"mise*-x64" \
    bpick"mise*-arm64" \
    sbin"mise*-arm64 -> mise" \
    sbin"mise*macos-x64 -> mise-x64" \
    atload"__mise_atload" \
    @'jdx/mise'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v2024.12.24" \
    sbin"mise* -> mise" \
    atload"__mise_atload" \
    @'jdx/mise'
fi

# navi #
zinit wait lucid light-mode blockf for \
    from"gh-r" cargo"navi" \
    ver"v2.22.1" \
    sbin"navi" \
    @'denisidoro/navi'

# tig #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    atclone"make configure && make prefix=$ZPFX install-release-doc" \
    atpull"%atclone" \
    ver"tig-2.5.10" \
    configure"!" \
    make"install PREFIX=$ZPFX" \
    @'jonas/tig'
fi

# ugrep #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    configure"!" \
    make"all install PREFIX=$ZPFX" \
    pick"bin/ug bin/ugrep" \
    sbin"bin/ug -> ug" \
    sbin"bin/ugrep -> ugrep" \
    @'Genivia/ugrep'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v4.4.1" \
    sbin"ug* -> ug" \
    sbin"ugrep* -> ugrep" \
    @'Genivia/ugrep'
fi

# up #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.4" \
    sbin"up* -> up" \
    @'akavel/up'

# yazi #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.2.5" \
    sbin"yazi*/yazi -> yazi" \
    @'sxyazi/yazi'
else
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v25.4.8" \
    sbin"yazi* -> yazi" \
    @'sxyazi/yazi'
fi

# zabrze #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.5.0" \
    as"program" \
    atload'eval "$(zabrze init --bind-keys)"' \
    @'Ryooooooga/zabrze'

# zoxide #
__zoxide_atload() {
    mkdir -p "$HOME/.local/state/zoxide" 2>/dev/null
    export _ZO_DATA_DIR="$HOME/.local/state/zoxide"
    eval "$(zoxide init zsh --cmd j)"
}
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.9.2" \
    sbin"zoxide" \
    atload"__zoxide_atload" \
    @'ajeetdsouza/zoxide'

# blueutil #
if [ "$(uname)" = "Darwin" ]; then
zinit wait lucid light-mode blockf for \
    make \
    sbin"blueutil" \
    @'toy/blueutil'
fi

### plugin ###
__zsh-autosuggestions_atload() {
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=100"
    _zsh_autosuggest_start
}
zinit wait lucid light-mode blockf for \
    atload"__zsh-autosuggestions_atload" \
    @'zsh-users/zsh-autosuggestions'

zinit wait lucid light-mode blockf for \
    atload"source autopair.zsh && autopair-init" \
    @'hlissner/zsh-autopair'

if [ "$(uname)" = "Darwin" ]; then
__zsh-auto-notify_atload() {
    export AUTO_NOTIFY_THRESHOLD=20
    AUTO_NOTIFY_IGNORE+=(
      "czg"
      "chezmoi apply"
      "git log"
      "git show"
      "git rebase"
      "gitui"
      "gh pr create"
      "gh pr diff"
      "gh pr edit"
    )
}
zinit wait lucid light-mode blockf for \
    atload"__zsh-auto-notify_atload" \
    @'MichaelAquilina/zsh-auto-notify'
fi

zinit wait lucid light-mode blockf for \
    @'zdharma/fast-syntax-highlighting'

### completion ###
zinit wait lucid light-mode blockf for \
    as"completion" \
    atload"zicompinit; zicdreplay" cp"git-completion.zsh -> _git" \
    "https://github.com/git/git/blob/master/contrib/completion/git-completion.zsh"

zinit wait lucid light-mode blockf for \
    silent \
    atclone"zstyle ':completion:*:*:git:*' script git-completion.bash" atpull"%atclone" \
    "https://github.com/git/git/blob/master/contrib/completion/git-completion.bash"

zinit wait lucid light-mode blockf for \
    as"completion" "https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker"

zinit wait lucid light-mode blockf for \
    as"completion" "https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/zsh/_docker-compose"

zinit wait lucid light-mode blockf for \
    as"completion" "https://github.com/Homebrew/brew/blob/master/completions/zsh/_brew"

zinit wait lucid light-mode blockf for \
    src"tmux" \
    as"completion" "https://github.com/imomaliev/tmux-bash-completion/blob/master/completions/tmux"

zinit wait lucid light-mode blockf for \
    atload"source zsh-better-npm-completion.plugin.zsh" \
    as"completion" "https://github.com/lukechilds/zsh-better-npm-completion/blob/master/zsh-better-npm-completion.plugin.zsh"

zinit wait lucid light-mode blockf for \
    as"completion" "https://github.com/jdx/mise/blob/main/completions/_mise"

zinit wait lucid light-mode blockf for \
    mv"chezmoi.zsh -> _chezmoi" \
    as"completion" "https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh"
