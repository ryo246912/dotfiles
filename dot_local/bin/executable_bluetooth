#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Bluetooth Connect Toggle
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Connect or disconnect Bluetooth devices interactively

# 全デバイスを取得
ALL_DEVICES=$(blueutil --paired --format json-pretty 2>/dev/null | jq -r '.[] | "\(.connected)|\(.name)|\(.address)"')

if [[ -z "$ALL_DEVICES" ]]; then
  echo "No paired devices found"
  exit 1
fi

# デバイスリストを作成（接続状態を表示）
DEVICE_LIST=""
while IFS='|' read -r connected name addr; do
  if [[ "$connected" == "true" ]]; then
    DEVICE_LIST+="\"🟢 $name (connected)\","
  else
    DEVICE_LIST+="\"⚪️ $name\","
  fi
done <<< "$ALL_DEVICES"

# 末尾のカンマを削除
DEVICE_LIST=${DEVICE_LIST%,}

# AppleScriptで選択ダイアログを表示
# AppleScriptで選択ダイアログを表示（フォーカス付き）
SELECTED=$(osascript <<EOF
tell application "System Events"
  activate
  set deviceList to {$DEVICE_LIST}
  choose from list deviceList with prompt "Select a device (🟢=connected, ⚪️=disconnected):" with title "Bluetooth Device Manager"
end tell
EOF
)

if [[ "$SELECTED" == "false" ]]; then
  echo "Cancelled"
  exit 0
fi

# 接続状態の記号を削除してデバイス名を取得
CLEAN_NAME=$(echo "$SELECTED" | sed 's/^🟢 //;s/^⚪️ //;s/ (connected)$//')

# デバイス情報を取得
DEVICE_INFO=$(echo "$ALL_DEVICES" | grep "|$CLEAN_NAME|")
IS_CONNECTED=$(echo "$DEVICE_INFO" | cut -d'|' -f1)
ADDR=$(echo "$DEVICE_INFO" | cut -d'|' -f3)

if [[ "$IS_CONNECTED" == "true" ]]; then
  # 切断
  echo "Disconnecting from $CLEAN_NAME..."
  blueutil --disconnect "$ADDR"

  if [[ $? -eq 0 ]]; then
    echo "✓ Disconnected from $CLEAN_NAME"
  else
    echo "✗ Failed to disconnect"
    exit 1
  fi
else
  # 接続
  echo "Connecting to $CLEAN_NAME..."
  blueutil --power 1 && blueutil --connect "$ADDR"

  if [[ $? -eq 0 ]]; then
    echo "✓ Connected to $CLEAN_NAME"
  else
    echo "✗ Failed to connect"
    exit 1
  fi
fi
