#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title GraphQL format
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description クリップボードの内容を"を取り除いて再度貼り付けます

if ! pbpaste | jq . >/dev/null 2>&1; then
  echo "Error: Clipboard content is not valid JSON"
  exit 1
fi

pbpaste | jq . | sed -E 's/^([[:space:]]*)"([^"]+)":/\1\2:/g' | pbcopy
