export WORDCHARS="*?_-.[]~&;=!#$%^(){}<>"

# 履歴ファイルの保存先。
# zsh は rc ファイル（= この .zshrc 経由の読込）を全て流した後、最初のプロンプトを出す前に
# HISTFILE を1回だけ読み込む。zinit の turbo（wait）で遅延読込される lazy/*.zsh で設定すると
# その読込に間に合わず、macOS の /etc/zshrc が設定する $ZDOTDIR/.zsh_history（過去の残骸）が
# 読まれてしまい、`exec $SHELL -l` 直後の履歴が数十件しか無い状態になる。
# （その後 share_history のインポートで実ファイルが読まれ、コマンドを1回実行すると全件見えるようになる）
# そのため HISTFILE だけは遅延させず、必ずここ（起動時）で設定する。
mkdir -p "$XDG_STATE_HOME/zsh" 2>/dev/null
export HISTFILE="$XDG_STATE_HOME/zsh/.zsh_history"
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
# 対話型シェルでのコメントを有効
setopt INTERACTIVE_COMMENTS
# 各セッションが終了時に履歴を上書きせず追記する
setopt APPEND_HISTORY
# コマンド実行のたびにすぐ履歴ファイルに書き込む
setopt INC_APPEND_HISTORY

if [ "$(uname)" = "Darwin" ]; then
  # ctrl + dは無効
  stty eof undef
  # ctrl + qは無効
  stty start undef
  # ctrl + sは無効
  stty stop undef
  # ctrl + zはsuspend
  stty susp ^Z
  # NOTE:sttyを変更するのは要注意
  # alt + shift + cはinterrupt
  # stty intr "^[C"
  # alt + shift + zはsuspend
  # stty susp "^[Z"
  stty susp undef
fi

zstyle ':completion:*:default' menu select=1
# makeコマンド補完
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':completion:*:*:make:*' tag-order 'targets'
