[[ -o interactive ]] || return

function git {
  local hook
  case "${1:-}" in
    checkout|switch)
      if [[ "${GIT_PRE_CHECKOUT:-}" != 0 ]] &&
        hook=$(command git config --type=path --get dotfiles.preCheckout) &&
        [[ -n "$hook" ]]; then
        if [[ ! -f "$hook" || ! -x "$hook" ]]; then
          print -ru2 -- "git: dotfiles.preCheckout is not executable: $hook"
          return 1
        fi
        "$hook" "$@" || return $?
      fi ;;
  esac
  command git "$@"
}
