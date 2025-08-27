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

# Clipboard #
zinit wait lucid light-mode blockf for \
    atclone"go build cmd/gocopy/gocopy.go && go build cmd/gopaste/gopaste.go" atpull"%atclone" \
    sbin"gocopy -> gocopy" \
    sbin"gopaste -> gopaste" \
    @'atotto/clipboard'

zinit wait lucid blockf for \
    "https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh" \
    "https://github.com/junegunn/fzf/blob/master/shell/completion.zsh"

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
      "git branch"
      "git log"
      "git show"
      "git rebase"
      "gh-dash"
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

__fast-syntax-highlighting_atload() {
    FAST_HIGHLIGHT_STYLES[comment]=white
}
zinit wait lucid light-mode blockf for \
    atload"__fast-syntax-highlighting_atload" \
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
    mv"chezmoi.zsh -> _chezmoi" \
    as"completion" "https://github.com/twpayne/chezmoi/blob/master/completions/chezmoi.zsh"
