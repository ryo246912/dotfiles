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

install_package() {
  local PACKAGES=(
    bitwarden-cli
    colordiff
    docker
    font-hackgen
    font-hackgen-nerd
    git
    go
    gpg
    mise
    pinentry-mac
    t-rec
    yqrashawn/goku/goku

    coreutils
    findutils
    gnu-sed
    grep
  )

  for package in "${PACKAGES[@]}"; do
    if ! brew list "$package" &>/dev/null; then
      brew install "$package"
    else
      echo "$package is already installed"
    fi
  done
}

install_cask_package() {
  local CASKPACKAGES=(
    alacritty
    arc
    battery
    chatgpt
    clibor
    dbeaver-community
    docker
    google-chrome
    google-japanese-ime
    karabiner-elements
    keyboardcleantool
    mise
    raycast
    slack
    thebrowsercompany-dia
    visual-studio-code
  )

  for package in "${CASKPACKAGES[@]}"; do
    if ! brew list --cask "$package" &>/dev/null; then
      if [[ "$package" == "clibor" ]]; then
        HOMEBREW_CASK_OPTS="--language=ja" brew install --cask "$package"
      elif [[ "$package" == "google-japanese-ime" ]]; then
        sudo softwareupdate --install-rosetta
        brew install --cask "$package"
      else
        brew install --cask "$package"
      fi
    else
      echo "$package is already installed"
    fi
  done
}

install_private_cask_package() {
  local CASKPACKAGES=(
    bitwarden
    claude
    google-drive
    obsidian
    thunderbird
  )

  for package in "${CASKPACKAGES[@]}"; do
    if ! brew list --cask "$package" &>/dev/null; then
        brew install --cask "$package"
    else
      echo "$package is already installed"
    fi
  done
}

setup_settings() {
  # メニューバーのアイコンの間隔を狭くする
  if ! defaults -currentHost read -globalDomain NSStatusItemSpacing &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSpacing)" -ne 6 ]; then
    defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
  fi
  if ! defaults -currentHost read -globalDomain NSStatusItemSelectionPadding &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSelectionPadding)" -ne 6 ]; then
    defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 6
  fi
  # Finder: 隠しファイルを表示する
  if [ "$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null)" -ne 1 ]; then
    defaults write com.apple.finder AppleShowAllFiles 1
  fi
  # Finder: 拡張子を表示する
  if [ "$(defaults read com.apple.finder AppleShowAllExtensions 2>/dev/null)" -ne 1 ]; then
    defaults write com.apple.finder AppleShowAllExtensions 1
  fi
  # Finder: パスのパンくずリストを表示する
  if [ "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)" -ne 1 ]; then
    defaults write com.apple.finder ShowPathbar 1
  fi
  # Finder: Finderを終了するメニューを表示する
  if [ "$(defaults read com.apple.Finder QuitMenuItem 2>/dev/null)" -ne 1 ]; then
    defaults write com.apple.Finder QuitMenuItem 1
  fi
  # キーボード: キーのリピート速度(小さい数値ほど速い)
  if [ "$(defaults read -g KeyRepeat 2>/dev/null)" -ne 2 ]; then
    defaults write -g KeyRepeat 2
  fi
  # キーボード: リピート入力認識までの時間(15ms/step、15 = 225ms)
  if [ "$(defaults read -g InitialKeyRepeat 2>/dev/null)" -ne 15 ]; then
    defaults write -g InitialKeyRepeat 15
  fi
  # トラックパッド: スクロール方向を順方向にする(NOTE:なぜかOFFが自然な方向になる)
  if [ "$(defaults read -g com.apple.swipescrolldirection 2>/dev/null)" -ne 0 ]; then
    defaults write -g com.apple.swipescrolldirection 0
  fi

  # ログイン時に開くアプリケーションを追加
  if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Clibor"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Clibor.app", hidden:false}'
  fi
  if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Docker"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}'
  fi
  if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Raycast"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Raycast.app", hidden:false}'
  fi

  # ショートカットの設定
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
  "install_package"
  "install_cask_package"
  "setup_settings"
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
