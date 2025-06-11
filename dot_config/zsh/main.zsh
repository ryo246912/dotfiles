export WORDCHARS="*?_-.[]~&;=!#$%^(){}<>"
export EDITOR=vim
export VIMINIT='let $MYVIMRC="~/.config/vim/.vimrc" | source $MYVIMRC'

# zshプロセスのメモリ上に保存される履歴の件数
HISTSIZE=10000
# ファイルに保存される履歴の件数
SAVEHIST=100000
# 同時に起動したzsh間でヒストリを共有
setopt share_history
# コマンドがリスト内で重複するの場合、古い方を削除
setopt hist_ignore_all_dups
# コマンドが前のイベントと重複する場合はリストに加えない
setopt hist_ignore_dups
# スペースで始まるコマンド行はヒストリから削除
setopt hist_ignore_space
# 余分な空白は詰めて記録
setopt hist_reduce_blanks
# ファイル書出の際、新しいコマンドと寿福する古いコマンドは無視
setopt hist_save_no_dups

zstyle ':completion:*:default' menu select=1
# makeコマンド補完
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':completion:*:*:make:*' tag-order 'targets'

# launch tmux when start zsh
if { [ "$TERM" = "alacritty" ] || [ "$TERM" = "rio" ] } && command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  tmux attach || tmux
fi
