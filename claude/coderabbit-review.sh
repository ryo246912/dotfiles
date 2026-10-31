#!/bin/bash
# 旧 hook 設定との互換用。正本は各 agent 共通のスクリプト。
f="$HOME/.config/devcontainer/scripts/coderabbit-review.sh"
[ -x "$f" ] || exit 0
exec "$f"
