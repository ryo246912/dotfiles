# tpmのインストール
if ! [ -e "$HOME/.config/tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
fi

# historyの保存先
mkdir -p "$XDG_STATE_HOME/node" 2>/dev/null
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node/.node_repl_history"
mkdir -p "$XDG_STATE_HOME/sqlite" 2>/dev/null
export SQLITE_HISTORY="$XDG_STATE_HOME/sqlite/.sqlite_history"
mkdir -p "$XDG_STATE_HOME/mysql" 2>/dev/null
export MYSQL_HISTFILE="$XDG_STATE_HOME/mysql/.mysql_history"
mkdir -p "$XDG_STATE_HOME/psql" 2>/dev/null
export PSQL_HISTORY="$XDG_STATE_HOME/psql/.psql_history"
mkdir -p "$XDG_STATE_HOME/less" 2>/dev/null
export LESSHISTFILE="$XDG_STATE_HOME/less/.lesshst"
mkdir -p "$XDG_STATE_HOME/zsh" 2>/dev/null
export HISTFILE="$XDG_STATE_HOME/zsh/.zsh_history"

# less
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# slack
export SLACK_DEVELOPER_MENU=true

# docker
export COMPOSE_MENU=0

# .zshrc.secretの読込
ZSH_SECRET_CONF="${HOME}/.zshrc.secret"
if [ -e "${ZSH_SECRET_CONF}" ]; then
  source "${ZSH_SECRET_CONF}"
fi

# 補完の読込
autoload -Uz compinit
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

if [ "$(uname)" = "Darwin" ]; then
  if [ $(date +'%j') != $(/usr/bin/stat -f '%Sm' -t '%j' "$HOME/.zcompdump") ]; then
    compinit
  else
    compinit -C
  fi
else
  compinit
fi
