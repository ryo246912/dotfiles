# ctrl + d(alt + shift + d)でlazygit起動
_lazygit() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" lazygit
  else
    BUFFER='lazygit'
    zle accept-line
  fi
}
zle -N _lazygit
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^D" _lazygit
else
  bindkey "^[D" _lazygit
fi

# ctrl + x(alt + shift + x)でgh-dash起動
_gh-dash() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" "tmux-popup-manager gh-dash"
  else
    BUFFER='gh-dash'
    zle accept-line
  fi
}
zle -N _gh-dash
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^X" _gh-dash
else
  bindkey "^[X" _gh-dash
fi

# ctrl + y(alt + shift + y)でyazi起動
_yazi() {
  if [ -n "$TMUX" ]; then
    # cf. https://github.com/sxyazi/yazi/issues/2308#issuecomment-2731102243
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" "tmux-popup-manager yazi _ZO_DATA_DIR=$HOME/.local/state/zoxide"
  else
    BUFFER='yazi'
    zle accept-line
  fi
}
zle -N _yazi
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^Y" _yazi
else
  bindkey "^[Y" _yazi
fi

# ctrl + g(alt + shift + g)でnavi widgetを呼び出し
_custom_navi_widget() {
  # [-b:buffer name][-d:delete buffer][-r:LFを自動で置換しない][-p:paste時にコマンドを自動で実行しない][-t:target pane]
  #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
  #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
  #複数の連続した空白を1つにする sed -e "s/  */ /g"
  if [ -n "$TMUX" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      tmux popup -xC -y "#{popup_pane_bottom}" -d "#{pane_current_path}" -w95% -h40% -E '\
        window=$(tmux display -p -F "#S:#I.#P") && \
        export FZF_DEFAULT_OPTS="-m --layout=reverse --border" && \
        TMP_BUFFER=$(navi --print) && \
        TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} && \
        TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} && \
        TMP_BUFFER=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$TMP_BUFFER") && \
        tmux set-buffer -b tmp "$TMP_BUFFER" && \
        tmux paste-buffer -drp -t $window -b tmp \
      '
    else
      tmux popup -xC -y "#{popup_pane_bottom}" -d "#{pane_current_path}" -w95% -h40% -E '\
        window=$(tmux display -p -F "#S:#I.#P") && \
        export FZF_DEFAULT_OPTS="-m --layout=reverse --border" && \
        TMP_BUFFER=$(navi --print) && \
        TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} && \
        TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} && \
        tmux set-buffer -b tmp "$TMP_BUFFER" && \
        tmux paste-buffer -drp -t $window -b tmp \
      '
    fi
  else
    local TMP_BUFFER
    #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
    #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
    #複数の連続した空白を1つにする sed -e "s/  */ /g"
    TMP_BUFFER=$(navi --print) && \
    TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} && \
    TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} && \
    TMP_BUFFER=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$TMP_BUFFER")
    BUFFER="$TMP_BUFFER"
    CURSOR=$#BUFFER #カーソルを末尾に移動
    zle redisplay
  fi
}
zle -N _custom_navi_widget
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^G' _custom_navi_widget
else
  bindkey '^[G' _custom_navi_widget
fi

# ctrl + q → ctrl + q(alt + shift + q → alt + shift + q)でnaviに登録されたpipe commandのsnippet呼び出し
_navi_insert_pipe_snippet() {
  #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
  #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
  #複数の連続した空白を1つにする sed -e "s/  */ /g"
  local word
  if [ -n "$TMUX" ]; then
    tmux popup -xC -y "#{popup_pane_bottom}" -d "#{pane_current_path}" -w95% -h40% -E '\
      export FZF_DEFAULT_OPTS="-m --layout=reverse --border" && \
      TMP_BUFFER=$(navi --print --query "shell:pipe-command ") && \
      TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} && \
      TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} && \
      TMP_BUFFER=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$TMP_BUFFER") && \
      tmux set-buffer -b tmp "$TMP_BUFFER" \
    '
    if tmux show-buffer -b tmp > /dev/null 2>&1 ; then
      word=$(tmux show-buffer -b tmp)
    fi
    tmux delete-buffer -b tmp
  else
    #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
    #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
    word=$(navi --print --query "shell:pipe-command ") && \
    word=${word%"${word##*[![:space:]]}"} && \
    word=${word#"${word%%[![:space:]]*}"} && \
    word=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$word")
  fi && \
  if [ -n "$word" ] && [[ $word =~ ">" ]] ; then
    BUFFER="$BUFFER $word"
    CURSOR=$#BUFFER #カーソルを末尾に移動
  elif [ -n "$word" ] ; then
    BUFFER="$BUFFER | $word"
    CURSOR=$#BUFFER #カーソルを末尾に移動
  fi
  zle redisplay
}
zle -N _navi_insert_pipe_snippet
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^Q' _navi_insert_pipe_snippet
else
  bindkey '^[Q^[Q' _navi_insert_pipe_snippet
fi

# ctrl + q → ctrl + a(alt + shift + q → alt + shift + a)で余分な空白を削除
_delete_space() {
  local TMP_BUFFER
  TMP_BUFFER=$BUFFER
  TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} #後方の空白文字を削除
  TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} #前方の空白文字を削除
  TMP_BUFFER=$((tr "\n\t" " " | sed -e 's/  */ /g') <<< "$TMP_BUFFER") #複数の連続した空白を1つにする
  BUFFER=$TMP_BUFFER
  zle redisplay
}
zle -N _delete_space
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^A' _delete_space
else
  bindkey '^[Q^[A' _delete_space
fi

# ctrl + q → ctrl + z(alt + shift + q → alt + shift + z)で先頭に#を追加 or 削除
_insert_comment() {
  if [[ $BUFFER =~ ^[[:space:]]*# ]]; then
      # 既にコメントアウトされている場合は解除
      BUFFER=${BUFFER#"${BUFFER%%[![:space:]]*}"}  # 前方の空白を削除
      BUFFER=${BUFFER#\#}  # #を削除
      BUFFER=${BUFFER#[[:space:]]}  # #の後の空白を削除
  else
      # コメントアウトされていない場合は追加
      BUFFER="# $BUFFER"
  fi
  zle redisplay
}
zle -N _insert_comment
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^Z' _insert_comment
else
  bindkey '^[Q^[Z' _insert_comment
fi

# ctrl + q → ctrl + s(alt + shift + q → alt + shift + s)でshortcut表示
_shortcut() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -y "#{popup_pane_bottom}" -d "#{pane_current_path}" -w95% -h40% -E '\
      export FZF_DEFAULT_OPTS="-m --layout=reverse --border" && \
      cat ~/.local/share/chezmoi/not_config/shortcut/list.csv | column -t -s, | fzf --no-sort --layout=reverse --border
    '
  else
    cat ~/.local/share/chezmoi/not_config/shortcut/list.csv | column -t -s, | fzf --no-sort --layout=reverse --border
  fi
}
zle -N _shortcut
bindkey '^Q^S' _shortcut

# ctrl + q → ctrl + g(alt + shift + q → alt + shift + g)でnaviのコマンドをクリップボードにコピー
_navi_copy_snippet() {
  # [-b:buffer name][-d:delete buffer][-r:LFを自動で置換しない][-p:paste時にコマンドを自動で実行しない][-t:target pane]
  #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
  #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
  #複数の連続した空白を1つにする sed -e "s/  */ /g"
  if [ -n "$TMUX" ]; then
    tmux popup -xC -y "#{popup_pane_bottom}" -d "#{pane_current_path}" -w95% -h40% -E '\
      export FZF_DEFAULT_OPTS="-m --layout=reverse --border" && \
      TMP_BUFFER=$(navi --print) && \
      TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"} && \
      TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"} && \
      TMP_BUFFER=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$TMP_BUFFER") && \
      tmux set-buffer -b tmp "$TMP_BUFFER" \
    '
    if tmux show-buffer -b tmp > /dev/null 2>&1 ; then
      tmux show-buffer -b tmp | cb
    fi && \
    tmux delete-buffer -b tmp
  else
    #後方の空白文字を削除 ${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
    #前方の空白文字を削除 ${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
    TMP_BUFFER=$(navi --print)
    TMP_BUFFER=${TMP_BUFFER%"${TMP_BUFFER##*[![:space:]]}"}
    TMP_BUFFER=${TMP_BUFFER#"${TMP_BUFFER%%[![:space:]]*}"}
    TMP_BUFFER=$((tr "\n" " " | sed -e "s/  */ /g") <<< "$TMP_BUFFER")
    echo "$TMP_BUFFER" | tr -d '\n' | cb
    zle redisplay
  fi
}
zle -N _navi_copy_snippet
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^G' _navi_copy_snippet
else
  bindkey '^[Q^[G' _navi_copy_snippet
fi

# ctrl + q → ctrl + w(alt + shift + q → alt + shift + w)でgit-worktree-managerを実行
_git_worktree_manager() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" "tmux-popup-manager git-worktree-manager"
  else
    BUFFER='git-worktree-manager'
    zle accept-line
  fi
}
zle -N _git_worktree_manager
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^Q^W" _git_worktree_manager
else
  bindkey "^[Q^[W" _git_worktree_manager
fi

# option + ↑で１つ上のディレクトリに移動
_cd-up () {
  BUFFER='cd ../'
  zle accept-line
}
zle -N _cd-up
bindkey '^[[1;3A' _cd-up

autoload -U modify-current-argument
# Esc + sで単語を''で囲む
_quote-previous-word-in-single() {
    modify-current-argument '${(qq)${(Q)ARG}}'
    zle vi-forward-blank-word
}
zle -N _quote-previous-word-in-single
bindkey '^[s' _quote-previous-word-in-single

# Esc + dで単語を""で囲む
_quote-previous-word-in-double() {
    modify-current-argument '${(qqq)${(Q)ARG}}'
    zle vi-forward-blank-word
}
zle -N _quote-previous-word-in-double
bindkey '^[d' _quote-previous-word-in-double
