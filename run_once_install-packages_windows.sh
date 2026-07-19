#!/bin/bash
[ "$(uname)" != "Linux" ] && exit

install_scoop() {
  if ! command -v scoop &>/dev/null; then
    powershell.exe -c "set-executionpolicy remotesigned -scope currentuser"
    powershell.exe -c "Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')"
  else
    echo "Scoop is already installed"
  fi
}

install_package() {
  # CLI（ugrep/tig 等）は mise（base config.toml の [bootstrap.packages] = apt:）で管理する。
  # ここにはブートストラップ前提のものだけ残す:
  #   - git : chezmoi の初回 clone に必要
  #   - gpg : mise の gpg_verify=true により `mise install` 前に必要（WSL は bootstrap 手動のため早期に）
  #   - zsh : ログインシェル（chsh）で早期に必要
  #   - mise: 本体（ループ内で curl https://mise.run により導入）
  local PACKAGES=(
    git
    gpg
    zsh
    mise
  )

  for package in "${PACKAGES[@]}"; do
    if [ "$package" = "mise" ]; then
      # mise は apt ではなく公式スクリプトで導入する（apt パッケージが無いため
      # elif の apt install へフォールスルーさせない）。
      if ! command -v mise &> /dev/null; then
        curl https://mise.run | sh
        # 本スクリプトは bash/sh で実行されるため zsh 用出力を eval すると構文エラーになり得る。
        # 後続で mise を使えるよう shims/bin に PATH を通すだけにする。
        export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
      else
        echo "mise is already installed"
      fi
    elif ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
      sudo apt install -y "$package"
    else
      echo "$package is already installed"
    fi
  done
  if command -v zsh &>/dev/null; then
    chsh -s "$(which zsh)"
  fi
}

install_scoop_package() {
  local PACKAGES=(
    alacritty
    bitwarden
    firefox
    obsidian
    thunderbird
    vscode
    extras/unigetui
    main/scoop-search
  )

  if ! scoop bucket list | grep -q "extras"; then
     scoop bucket add extras
  fi

  for package in "${PACKAGES[@]}"; do
    package_name="${package##*/}"
    if ! scoop list | awk '{print $1}' | grep -Fxq "$package_name"; then
      scoop install "$package"
    else
      echo "$package_name is already installed"
    fi
  done
}

install_private_scoop_package() {
  local PACKAGES=(
    musicbee
    NeeView
  )

  for package in "${PACKAGES[@]}"; do
    if ! scoop list | grep -q "$package"; then
      scoop install "$package"
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
  "install_scoop"
  "install_package"
  "install_scoop_package"
  "install_private_scoop_package"
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
