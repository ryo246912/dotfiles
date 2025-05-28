# glow #
__glow_atclone() {
  if [ "$(uname)" = "Darwin" ]; then
      [ -e "$HOME/.config/glow/glow.yml" ] && ln -f "$HOME/.config/glow/glow.yml" "$HOME/Library/Preferences/glow/glow.yml"
  fi
}
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v2.1.0" \
    sbin"glow" \
    atclone"__glow_atclone" \
    @'charmbracelet/glow'

# ijq #
zinit wait lucid light-mode blockf for \
    make \
    sbin"ijq -> ijq" \
    @'gpanders/ijq'

# koji #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v3.1.0" \
    sbin"koji* -> koji" \
    @'cococonscious/koji'

# spacer #
zinit wait lucid light-mode blockf for \
    from"gh-r" \
    ver"v0.3.0" \
    sbin"spacer* -> spacer" \
    @'samwho/spacer'

## programs ##
zinit wait lucid light-mode blockf for \
    as"program" pick"fzf-tmux" \
    "https://github.com/junegunn/fzf/blob/master/bin/fzf-tmux"

