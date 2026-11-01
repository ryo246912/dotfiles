#!/bin/bash
# rulesync の PreToolUse hook。stdin の JSON を共通実装へ渡す。
exec python3 "$(dirname "$0")/coderabbit-review.py" "$@"
