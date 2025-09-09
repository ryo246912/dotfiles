alias vim="nvim"

claude_check_version() {
  local desired_version="1.0.48"
  local current_version=$(command claude --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -n 1)

  if [ -z "$current_version" ]; then
    echo "Error: Could not determine claude version. Is 'claude' command available?" >&2
    return 1
  fi

  if [ "$current_version" = "$desired_version" ]; then
    command claude "$@"
  else
    echo "Warning: claude version ($current_version) does not match desired version ($desired_version). Not running 'claude'." >&2
    return 1
  fi
}

# alias claude="claude_check_version"

if [ "$(uname)" = "Linux" ]; then
  # powershell
  alias pwsh="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
  alias powershell="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
fi
