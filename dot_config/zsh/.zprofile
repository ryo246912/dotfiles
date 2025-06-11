# パスの重複を除く
typeset -U path PATH

if [ "$(uname)" = "Darwin" ]; then
  path=(
    $HOME/{,s}bin(N)
    /{opt,user}/local/{,s}bin(N)
    /opt/homebrew/opt/coreutils/libexec/gnubin(N)
    /opt/homebrew/opt/findutils/libexec/gnubin(N)
    /opt/homebrew/opt/grep/libexec/gnubin(N)
    /opt/homebrew/opt/gnu-sed/libexec/gnubin(N)
    $HOME/.cargo/bin(N)
    $HOME/go/bin(N)
    $path
  )
else
  path=(
    $HOME/{,s}bin(N)
    /{opt,user}/local/{,s}bin(N)
    $HOME/.cargo/bin(N)
    $HOME/go/bin(N)
    $path
  )
fi

# .zprofile.secretの読込
ZPROFILE_SECRET_CONF="${HOME}/.zprofile.secret"
if [ -e "${ZPROFILE_SECRET_CONF}" ]; then
  source "${ZPROFILE_SECRET_CONF}"
fi

