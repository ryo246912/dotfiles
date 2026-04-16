# keychain-cli: A wrapper for macOS security command to manage secrets in Keychain.
# Inspired by: https://x.com/RomanVDev/status/2044688769287106784

keychain-cli() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: keychain-cli is only supported on macOS." >&2
    return 1
  fi

  local command=$1
  shift

  case "$command" in
    get)
      local account=$1
      if [[ -z "$account" ]]; then
        echo "Usage: keychain-cli get <account>" >&2
        return 1
      fi
      # -w: output only the password/secret
      security find-generic-password -s "keychain-cli" -a "$account" -w 2>/dev/null
      ;;
    set)
      local account=$1
      local secret=$2
      if [[ -z "$account" ]]; then
        echo "Usage: keychain-cli set <account> [secret]" >&2
        return 1
      fi
      if [[ -z "$secret" ]]; then
        echo -n "Enter secret for $account: "
        read -rs secret
        echo
      fi
      # -a: account name, -s: service name, -w: password
      # -U: update if exists
      security add-generic-password -a "$account" -s "keychain-cli" -w "$secret" -U
      ;;
    delete)
      local account=$1
      if [[ -z "$account" ]]; then
        echo "Usage: keychain-cli delete <account>" >&2
        return 1
      fi
      security delete-generic-password -a "$account" -s "keychain-cli"
      ;;
    list)
      security find-generic-password -s "keychain-cli" 2>/dev/null | grep "acct" | cut -d'=' -f2 | tr -d '"'
      ;;
    *)
      echo "Usage: keychain-cli {get|set|delete|list} [args]" >&2
      return 1
      ;;
  esac
}

# Basic Zsh completion for keychain-cli
_keychain-cli() {
  local -a commands
  commands=(
    'get:Get a secret'
    'set:Set a secret'
    'delete:Delete a secret'
    'list:List all accounts stored with keychain-cli'
  )

  if (( CURRENT == 2 )); then
    _describe -t commands 'keychain-cli command' commands
  elif (( CURRENT == 3 )); then
    case $words[2] in
      get|delete)
        local -a accounts
        accounts=($(keychain-cli list))
        _describe -t accounts 'accounts' accounts
        ;;
    esac
  fi
}

compdef _keychain-cli keychain-cli
