#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Bluetooth Connect Toggle
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Connect or disconnect Bluetooth devices interactively

# 全デバイスを取得してデバイスリストを作成
DEVICE_LIST=$(blueutil --paired --format json-pretty 2>/dev/null | jq -r 'map("\(if .connected then "🟢 " else "⚪️ " end)\(.name)\(if .connected then " (connected)" else "" end)") | map("\"" + . + "\"") | join(",")' | tr -d '\n')

if [[ -z "$DEVICE_LIST" ]]; then
  echo "No paired devices found"
  exit 1
fi

# AppleScriptで選択ダイアログを表示
# AppleScriptで選択ダイアログを表示（フォーカス付き）
SELECTED=$(osascript <<EOF
tell application "System Events"
  activate
  set deviceList to {$DEVICE_LIST}
  choose from list deviceList with prompt "Select a device" & linefeed & "(🟢=connected, ⚪️=disconnected):" with title "Bluetooth Device Manager"
end tell
EOF
)

if [[ "$SELECTED" == "false" ]]; then
  echo "Cancelled"
  exit 0
fi

# 接続状態の記号を削除してデバイス名を取得
CLEAN_NAME=$(echo "$SELECTED" | sed 's/^🟢 //;s/^⚪️ //;s/ (connected)$//')

# jqでデバイス情報をJSON形式で取得
DEVICE_DATA=$(blueutil --paired --format json-pretty 2>/dev/null | jq ".[] | select(.name == \"$CLEAN_NAME\")")

IS_CONNECTED=$(echo "$DEVICE_DATA" | jq -r '.connected')
ADDR=$(echo "$DEVICE_DATA" | jq -r '.address')

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
