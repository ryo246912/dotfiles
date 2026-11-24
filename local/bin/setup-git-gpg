#!/bin/bash

# --- 設定するGPGキーID (必須) ---
# gpg --list-secret-keys --keyid-format LONG で確認したキーIDを設定してください
# ----------------------------------
# sec   rsa4096/XXXXXXXXXXXXXXXX  2023-01-01 [SC]
#       YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
# uid                 [ultimate] Your Name <your.email@example.com>
# ssb   rsa4096/ZZZZZZZZZZZZZZZZ  2023-01-01 [E]
GPG_KEY_ID="08BF9A27112516E5" # 例: 0xABCDEFGHIJKLMNOP

# --- Gitのユーザー情報 (GPGキーと一致させることを推奨) ---
GIT_USER_NAME="ryo246912"
GIT_USER_EMAIL="r-k.sky_25cloudf@hotmail.co.jp"

# --- GPGキーIDのチェック ---
if [ "$GPG_KEY_ID" == "XXXXXXXXXXXXXXXX" ]; then
    echo "エラー: GPG_KEY_ID を正しいキーIDに置き換えてください。"
    exit 1
fi

# コマンド実行、confirm_and_execute "説明" "関数名"
confirm_and_execute() {
  local description="$1"
  local function_name="$2"

  echo "$description"
  while true; do
    echo "を実行しますか? (y/n)"
    read -r answer

    case "$answer" in
      y|Y)
        "$function_name"
        break
        ;;
      n|N)
        echo "スキップしました。"
        break
        ;;
      *)
        echo "無効な入力です。y または n を入力してください。"
        ;;
    esac
  done
}

# Git設定関数
setup_git_user() {
  if git config --list | grep "user.name=$GIT_USER_NAME" &>/dev/null; then
    echo "Gitのユーザー情報は既に設定されています"
  else
    git config --global user.name "$GIT_USER_NAME"
  fi
  if git config --list | grep "user.email=$GIT_USER_EMAIL" &>/dev/null; then
    echo "Gitのメールアドレスは既に設定されています"
  else
    git config --global user.email "$GIT_USER_EMAIL"
  fi
  echo "設定完了: user.name = $GIT_USER_NAME, user.email = $GIT_USER_EMAIL"
}

# GPGキー設定関数
setup_gpg_key() {
  if git config --list | grep "user.signingkey=$GPG_KEY_ID" &>/dev/null; then
    echo "GitのGPG署名キーは既に設定されています"
  else
    git config --global user.signingkey "$GPG_KEY_ID"
  fi
  echo "設定完了: user.signingkey = $GPG_KEY_ID"
}

# GPGエージェントの設定
setup_gpg_agent() {
  GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
  if [ ! -f "$GPG_AGENT_CONF" ]; then
    echo "gpg-agent の設定ファイルを作成"
    mkdir -p "$HOME/.gnupg"
    if [ "$(uname)" = "Darwin" ]; then
      echo "default-cache-ttl 600" >> "$GPG_AGENT_CONF"
      echo "max-cache-ttl 7200" >> "$GPG_AGENT_CONF"
      echo "pinentry-program $(which pinentry-mac)" >> "$GPG_AGENT_CONF"
    else
      echo "default-cache-ttl 600" >> "$GPG_AGENT_CONF"
      echo "max-cache-ttl 7200" >> "$GPG_AGENT_CONF"
      echo "allow-loopback-pinentry" >> "$GPG_AGENT_CONF"
      echo "pinentry-program /usr/bin/pinentry-curses" >> "$GPG_AGENT_CONF"
      echo "pinentry-mode loopback" >> "$GPG_AGENT_CONF"
      echo "extra-socket /tmp/gpg-agent-extra-socket" >> "$GPG_AGENT_CONF"
    fi
    echo "設定ファイル $GPG_AGENT_CONF を作成しました。"
  else
    echo "gpg-agent の設定ファイルは既に存在します ($GPG_AGENT_CONF)。"
  fi

  gpgconf --kill gpg-agent
}

echo "--- Git GPG 署名設定を開始します ---"

confirm_and_execute "1. Gitのユーザー情報を設定" "setup_git_user"

confirm_and_execute "2. GitにGPG署名キーを設定" "setup_gpg_key"

confirm_and_execute "3. GPGエージェントを設定" "setup_gpg_agent"

echo "--- 設定完了 ---"
