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
    font-hackgen
    font-hackgen-nerd
    mise
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
  # 他の cask は dot_config/mise/config.mac.toml の [bootstrap.packages]（brew-cask:）で管理。
  # ここに残る3つは brew-cask では扱えないため手動インストールを維持する:
  #   clibor              -> custom install option（--language=ja）
  #   google-japanese-ime -> Rosetta が前提
  #   thock               -> 独自 tap + postflight（thock --install）
  local PACKAGES=(
    clibor
    google-japanese-ime
    thock
  )

  for package in "${PACKAGES[@]}"; do
    if [[ "$package" == "thock" ]]; then
      # thock は tap 経由の formula としてインストールされるため --cask では判定できない
      if ! brew list "$package" &>/dev/null; then
        brew tap kamillobinski/thock
        brew install "$package"
        thock --install
      else
        echo "$package is already installed"
      fi
    elif ! brew list --cask "$package" &>/dev/null; then
      if [[ "$package" == "clibor" ]]; then
        HOMEBREW_CASK_OPTS="--language=ja" brew install --cask "$package"
      elif [[ "$package" == "google-japanese-ime" ]]; then
        sudo softwareupdate --install-rosetta
        brew install --cask "$package"
      fi
    else
      echo "$package is already installed"
    fi
  done
}

install_work_package() {
  local PACKAGES=(
    jira-cli
  )

  for package in "${PACKAGES[@]}"; do
    if ! brew list "$package" &>/dev/null; then
      if [[ "$package" == "jira-cli" ]]; then
        brew tap ankitpokhrel/jira-cli
        brew install "$package"
      else
        brew install "$package"
      fi
    else
      echo "$package is already installed"
    fi
  done
}

setup_settings() {
  # 隠しファイル表示・拡張子表示・パスバー・KeyRepeat 等は
  # dot_config/mise/config.mac.toml の [bootstrap.macos.*] へ移行済み
  # （`mise bootstrap macos defaults apply` で適用）。
  # メニューバーのアイコン間隔は `defaults -currentHost` 前提で mise 未対応のためここに残す。
  if ! defaults -currentHost read -globalDomain NSStatusItemSpacing &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSpacing)" -ne 6 ]; then
    defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
  fi
  if ! defaults -currentHost read -globalDomain NSStatusItemSelectionPadding &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSelectionPadding)" -ne 6 ]; then
    defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 6
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
  "install_work_package"
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
