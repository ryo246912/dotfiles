# ctrl + d(alt + shift + d)でgitui起動
_gitui() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" gitui
  else
    BUFFER='gitui'
    zle accept-line
  fi
}
zle -N _gitui
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^D" _gitui
else
  bindkey "^[D" _gitui
fi

# ctrl + w(alt + shift + w)でgitui起動
_gh-dash() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" gh-dash
  else
    BUFFER='gh-dash'
    zle accept-line
  fi
}
zle -N _gh-dash
if [ "$(uname)" = "Darwin" ]; then
  bindkey "^W" _gh-dash
else
  bindkey "^[W" _gh-dash
fi

# ctrl + y(alt + shift + y)でyazi起動
_yazi() {
  if [ -n "$TMUX" ]; then
    tmux popup -xC -yC -w95% -h95% -E -d "#{pane_current_path}" yazi
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

# ctrl + q → ctrl + z(alt + shift + q → alt + shift + z)でコマンド履歴を選択して出力
_fzf_insert_command() {
  local num command line array1 array2 word
  command=$(cat <(echo "$BUFFER") <(history -100000 | cut -f 4- -d " " | tac) | fzf)
  if [ -n "$command" ] ; then
    BUFFER="$BUFFER $command"
    CURSOR=$#BUFFER #カーソルを末尾に移動
  fi
  zle redisplay
}
zle -N _fzf_insert_command
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^Z' _fzf_insert_command
else
  bindkey '^[Q^[Z' _fzf_insert_command
fi

# ctrl + q → ctrl + x(alt + shift + q → alt + shift + x)でコマンド履歴からwordを選択して出力
_fzf_insert_command_word() {
  local num command line array1 array2 word
  command=$(cat <(echo "$BUFFER") <(history -100000 | cut -f 4- -d " " | tac) | fzf)
  if [ -n "$command" ] ; then
    for i in $(seq $(echo "$command" | wc -m)) ; do
      array1+=( "$(cut -c $i- <(echo $command))\n" )
    done
  fi
  if [ -n "${array1[*]}" ] ; then
    line=$(echo -e "${array1[@]}" | fzf)
    num=$(echo "$line" | wc -m)
    for j in $(seq $num) ; do
      array2+=( "$(cut -c -$((num-j+1)) <(echo $line))\n" )
    done
  fi
  if [ -n "${array2[*]}" ] ; then
    word=$(echo -e "${array2[@]}" | fzf)
    word=${word#"${word%%[![:space:]]*}"} #前方の空白文字を削除
    word=${word%"${word##*[![:space:]]}"} #後方の空白文字を削除
    word=$(echo "$word" | tr -d '\n')
  fi
  if [ -n "$word" ] ; then
    BUFFER="$BUFFER $word"
    CURSOR=$#BUFFER #カーソルを末尾に移動
  fi
  zle redisplay
}
zle -N _fzf_insert_command_word
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^X' _fzf_insert_command_word
else
  bindkey '^[Q^[X' _fzf_insert_command_word
fi

# ctrl + q → ctrl + w(alt + shift + q → alt + shift + w)で画面キャプチャしてwordを選択してコピー
_copy_word() {
  local num line1 line2 array1 array2 word
  line1=$(tmux capture-pane -p | fzf)
  if [ -n "$line1" ] ; then
    for i in $(seq $(echo "$line1" | wc -m)) ; do
      array1+=( "$(cut -c $i- <(echo $line1))\n" )
    done
  fi
  if [ -n "${array1[*]}" ] ; then
    line2=$(echo -e "${array1[@]}" | fzf)
    num=$(echo "$line2" | wc -m)
    for j in $(seq $num) ; do
      array2+=( "$(cut -c -$((num-j+1)) <(echo $line2))\n" )
    done
  fi
  if [ -n "${array2[*]}" ] ; then
    word=$(echo -e "${array2[@]}" | fzf)
    word=${word%"${word##*[![:space:]]}"} #後方の空白文字を削除
    word=${word#"${word%%[![:space:]]*}"} #前方の空白文字を削除
  fi
  if [ -n "$word" ] ; then
    echo "$word" | tr -d '\n' | cb
  fi
  zle redisplay
}
zle -N _copy_word
if [ "$(uname)" = "Darwin" ]; then
  bindkey '^Q^W' _copy_word
else
  bindkey '^[Q^[W' _copy_word
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
