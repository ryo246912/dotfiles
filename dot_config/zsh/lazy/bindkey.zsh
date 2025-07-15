# キーバインドをemacs風にする
# bindkey -e
# キーバインドをvi風にする
bindkey -v

# shift + Tabで逆Tab方向に移動
bindkey '^[[Z' reverse-menu-complete

# option(alt) + ←→で単語毎のカーソル移動
bindkey "^[[1;3C" forward-word
bindkey -M vicmd "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word
bindkey -M vicmd "^[[1;3D" backward-word

# option + ←→で単語毎のカーソル移動(rio)
bindkey "^[f" forward-word
bindkey -M vicmd "^[f" forward-word
bindkey "^[b" backward-word
bindkey -M vicmd "^[b" backward-word

# option(alt) + shift + ←で単語毎の削除
bindkey "^[[1;4D" backward-kill-word

if [ "$(uname)" = "Darwin" ]; then
  # viinsのkeymapにemacsのコマンドを設定
  bindkey -M viins '^A'  beginning-of-line
  bindkey -M viins '^B'  backward-char
  bindkey -M viins '^E'  end-of-line
  bindkey -M viins '^F'  forward-char
  bindkey -M viins '^H'  backward-delete-char
  bindkey -M viins '^K'  kill-line
  bindkey -M viins '^N'  history-search-forward
  bindkey -M viins '^P'  history-search-backward
  bindkey -M viins '^U'  backward-kill-line
  bindkey -M viins '^Xv' quoted-insert
  bindkey -M viins '^W'  backward-kill-word
else
  # ctrl-modifierのkeymapを削除
  bindkey -M viins -r "^@"
  bindkey -M viins -r "^A"
  bindkey -M viins -r "^B"
  bindkey -M viins -r "^C"
  bindkey -M viins -r "^D"
  bindkey -M viins -r "^E"
  bindkey -M viins -r "^F"
  bindkey -M viins -r "^G"
  bindkey -M viins -r "^H"
  bindkey -M viins -r "^I"
  bindkey -M viins -r "^J"
  bindkey -M viins -r "^K"
  bindkey -M viins -r "^L"
  bindkey -M viins -r "^M"
  bindkey -M viins -r "^N"
  bindkey -M viins -r "^O"
  bindkey -M viins -r "^P"
  bindkey -M viins -r "^Q"
  bindkey -M viins -r "^Q^A"
  bindkey -M viins -r "^Q^G"
  bindkey -M viins -r "^Q^Q"
  bindkey -M viins -r "^Q^W"
  bindkey -M viins -r "^Q^X"
  bindkey -M viins -r "^Q^Z"
  bindkey -M viins -r "^R"
  bindkey -M viins -r "^S"
  bindkey -M viins -r "^T"
  bindkey -M viins -r "^U"
  bindkey -M viins -r "^V"
  bindkey -M viins -r "^W"
  bindkey -M viins -r "^X^R"
  bindkey -M viins -r "^X?"
  bindkey -M viins -r "^XC"
  bindkey -M viins -r "^Xa"
  bindkey -M viins -r "^Xc"
  bindkey -M viins -r "^Xd"
  bindkey -M viins -r "^Xe"
  bindkey -M viins -r "^Xh"
  bindkey -M viins -r "^Xm"
  bindkey -M viins -r "^Xn"
  bindkey -M viins -r "^Xt"
  bindkey -M viins -r "^Xv"
  bindkey -M viins -r "^X~"
  bindkey -M viins -r "^Y"
  bindkey -M viins -r "^Z"
  # viinsのkeymapにemacsのコマンドを設定(shift + alt-modifier)
  bindkey -M viins '^[A'  beginning-of-line
  bindkey -M viins '^[B'  backward-char
  bindkey -M viins '^[E'  end-of-line
  bindkey -M viins '^[F'  forward-char
  bindkey -M viins '^[H'  backward-delete-char
  bindkey -M viins '^[K'  kill-line
  bindkey -M viins '^[N'  history-search-forward
  bindkey -M viins '^[P'  history-search-backward
  bindkey -M viins '^[U'  backward-kill-line
  bindkey -M viins '^[Xv' quoted-insert
  bindkey -M viins '^[W'  backward-kill-word
fi

if [ "$(uname)" = "Darwin" ]; then
  # ctrl + p/nをhistory-search-xxxに変更
  bindkey "^N" history-search-forward
  bindkey "^P" history-search-backward
else
  # alt + shift + p/nをhistory-search-xxxに変更
  bindkey "^[N" history-search-forward
  bindkey "^[P" history-search-backward
fi
