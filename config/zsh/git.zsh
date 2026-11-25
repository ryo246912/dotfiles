[[ -o interactive ]] || return

_dotfiles_pre_checkout() (
  # Append command-line config with the same quoting and precedence as Git.
  add_config() {
    local quoted=${1//\'/\'\\\'\'}
    export GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }'$quoted'"
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -C)
        [[ $# -ge 2 ]] || return 0
        case "$2" in
          '') ;;
          /*) cd -P -- "$2" 2>/dev/null || return 0 ;;
          *) cd -P -- "./$2" 2>/dev/null || return 0 ;;
        esac
        shift 2 ;;
      -c)
        [[ $# -ge 2 ]] || return 0
        add_config "$2"
        shift 2 ;;
      --git-dir|--work-tree)
        [[ $# -ge 2 ]] || return 0
        if [[ "$1" == --git-dir ]]; then
          export GIT_DIR="$2"
        else
          export GIT_WORK_TREE="$2"
        fi
        shift 2 ;;
      --git-dir=*|--work-tree=*)
        case "$1" in
          --git-dir=*) export GIT_DIR="${1#*=}" ;;
          --work-tree=*) export GIT_WORK_TREE="${1#*=}" ;;
        esac
        shift ;;
      --literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--no-pager|-P|--paginate|-p|--no-optional-locks)
        shift ;;
      checkout|switch)
        local hook
        hook=$(command git config --type=path --get dotfiles.preCheckout 2>/dev/null) || return 0
        [[ -f "$hook" && -x "$hook" ]] || return 0
        "$hook" "$@"
        return $? ;;
      *) return 0 ;;
    esac
  done
)

function git {
  if [[ "${GIT_PRE_CHECKOUT:-}" != 0 ]]; then
    _dotfiles_pre_checkout "$@" || return $?
  fi
  command git "$@"
}
