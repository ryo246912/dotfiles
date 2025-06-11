#!/bin/bash
[ "$(uname)" != "Linux" ] && exit

install_package() {
  local PACKAGES=(
    git
    gpg
    zsh
  )

  for package in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "$package"; then
      apt install -y "$package"
    else
      echo "$package is already installed"
    fi
  done
}

install_nix() {
  if ! command -v nix &>/dev/null; then
    true
    # curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
  else
    echo "Nix is already installed"
  fi
}


# 実行したいコマンドを入力
commands=(
  "install_package"
  "install_nix"
)

execute_command() {
  local command="$1"

  while true; do
    echo "$command"
    echo "を実行しますか? (y/n)"
    read -r answer

    case "$answer" in
      y|Y)
        eval "$command"
        break
        ;;
      n|N)
        break
        ;;
      *)
        echo "無効な入力です。y または n を入力してください。"
        ;;
    esac
  done
}

for cmd in "${commands[@]}"; do
  execute_command "$cmd"
done
