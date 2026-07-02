#!/bin/bash
[ "$(uname)" != "Darwin" ] && exit

install_brew() {
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    source "$ZDOTDIR/.zshrc"
  else
    echo "Homebrew is already installed"
  fi
}

install_cask_package() {
  local PACKAGES=(
    alacritty
    arc
    battery
    chatgpt
    clibor
    dbeaver-community
    docker
    firefox
    ghostty
    google-chrome
    google-japanese-ime
    karabiner-elements
    keyboardcleantool
    raycast
    slack
    thock
    thebrowsercompany-dia
    visual-studio-code
    wezterm@nightly
    zoom
  )

  for package in "${PACKAGES[@]}"; do
    if ! brew list --cask "$package" &>/dev/null; then
      if [[ "$package" == "clibor" ]]; then
        HOMEBREW_CASK_OPTS="--language=ja" brew install --cask "$package"
      elif [[ "$package" == "google-japanese-ime" ]]; then
        sudo softwareupdate --install-rosetta
        brew install --cask "$package"
      elif [[ "$package" == "thock" ]]; then
        brew tap kamillobinski/thock
        brew install "$package"
        thock --install
      else
        brew install --cask "$package"
      fi
    else
      echo "$package is already installed"
    fi
  done
}

install_private_cask_package() {
  local PACKAGES=(
    bitwarden
    claude
    google-drive
    obsidian
    tailscale-app
    termius
    thunderbird
  )

  for package in "${PACKAGES[@]}"; do
    if ! brew list --cask "$package" &>/dev/null; then
        brew install --cask "$package"
    else
      echo "$package is already installed"
    fi
  done
}

setup_shortcuts() {
  while true; do
    echo "ショートカットの設定を実行しますか? (y/n)"
    read -r answer

    case "$answer" in
      y|Y)
        # option + tabでアプリケーションの切り替え
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 27 "
          <dict>
            <key>enabled</key>
            <true/>
            <key>value</key>
            <dict>
              <key>parameters</key>
              <array>
                <integer>65535</integer>
                <integer>48</integer>
                <integer>524288</integer>
              </array>
              <key>type</key>
              <string>standard</string>
            </dict>
          </dict>
        "
        # ctrl + ↓で通知センターを表示
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 163 "
          <dict>
            <key>enabled</key>
            <true/>
            <key>value</key>
            <dict>
              <key>parameters</key>
              <array>
                <integer>65535</integer>
                <integer>48</integer>
                <integer>524288</integer>
              </array>
              <key>type</key>
              <string>standard</string>
            </dict>
          </dict>
        "
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

install_nix() {
  if ! command -v nix &>/dev/null; then
    # nix-installerでインストール
    # https://github.com/DeterminateSystems/nix-installer
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  else
    echo "Nix is already installed"
  fi
}

# 実行したいコマンドを入力
commands=(
  "install_brew"
  "install_cask_package"
  "setup_shortcuts"
  # "install_nix"
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
