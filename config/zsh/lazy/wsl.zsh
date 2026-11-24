[ "$(uname)" != "Linux" ] && return

# gpg
export GPG_TTY=$(tty)
# 現在のTTYを gpg-agent に通知
gpg-connect-agent updatestartuptty /bye > /dev/null
gpgconf --launch gpg-agent

# fly
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
