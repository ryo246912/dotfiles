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
  # ここにはブートストラップ前提のものだけ残す:
  #   - gpg : mise の gpg_verify=true により `mise install` 前に必要（WSL は bootstrap 手動のため早期に）
  #   - zsh : ログインシェル（chsh）で早期に必要
  local PACKAGES=(
    gpg
    zsh
  )

  for package in "${PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
      sudo apt install -y "$package"
    else
      echo "$package is already installed"
    fi
  done
  if command -v zsh &>/dev/null; then
    chsh -s "$(which zsh)"
  fi
}

install_mise() {
  # apt / OS パッケージ版の mise はデフォルト feature (native-tls) ビルドで
  # TLS 1.3 必須のホストに接続できないため、rustls ビルドの公式バイナリを入れる。
  # (mise の http backend が TLS 1.3 必須のサーバーからダウンロードできるようにする)
  # https://github.com/rust-native-tls/rust-native-tls/issues/305
  # ガードは公式インストール先のパスで判定する。apt 版(native-tls)が入っていても
  # 早期 return せず、rustls ビルドの公式バイナリで確実に上書きする。
  if [ -x "$HOME/.local/bin/mise" ]; then
    echo "mise (official binary) is already installed"
    return
  fi
  curl -fsSL https://mise.run | sh
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
  "install_mise"
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
