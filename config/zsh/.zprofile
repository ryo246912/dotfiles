# macOS の /etc/zprofile は `/usr/libexec/path_helper -s` を eval し、/etc/paths・
# /etc/paths.d から PATH を再構築したうえで既存エントリを末尾へ回す。zsh の読み込み順は
# ~/.zshenv → /etc/zprofile → $ZDOTDIR/.zprofile なので、.zshenv で先頭に置いた
# /opt/homebrew/bin・mise shims・gnubin はこの時点で /usr/bin 等の後ろに落ちている。
# path_helper より後に走るここで .zshenv 定義の関数を呼び直し、意図した順序へ戻す。
if typeset -f __zsh_setup_path > /dev/null; then
  __zsh_setup_path
fi

# .zprofile.secretの読込
ZPROFILE_SECRET_CONF="${HOME}/.zprofile.secret"
if [ -e "${ZPROFILE_SECRET_CONF}" ]; then
  source "${ZPROFILE_SECRET_CONF}"
fi

