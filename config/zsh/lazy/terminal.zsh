[ "$(uname)" != "Darwin" ] && return

# iTerm2
tab-color() {
  echo -ne "\033]6;1;bg;red;brightness;$1\a"
  echo -ne "\033]6;1;bg;green;brightness;$2\a"
  echo -ne "\033]6;1;bg;blue;brightness;$3\a"
}

tab-reset() {
  echo -ne "\033]6;1;bg;*;default\a"
}

chpwd() {
  if [ "$TERM" = "xterm-256color" ]; then
    case $PWD/ in
      ~) tab-color 0 200 0;;
      *) tab-reset;;
    esac
    echo -ne "\033]0;$(pwd | rev | awk -F \/ '{print "/"$1"/"$2}'| rev)\007"
  fi

  if [ "$TERM" = "screen-256color" ]; then
    case $PWD in
      ~) tmux set-option -w window-status-format '#[bg=#008000] #I #{b:pane_current_path} ' ;;
      *) tmux set-option -w window-status-format '#[bg=#808080] #I #{b:pane_current_path} ' ;;
    esac
  fi
}
