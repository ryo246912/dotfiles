---
root: true
targets:
  - copilot
globs:
  - "**/*"
---

- 必ず日本語で回答してください。

## RTK の使い方

- shell command は可能な限り `rtk` を前置して実行してください。
- VS Code Copilot Chat は hook で `updatedInput` により自動書き換えされます。
- Copilot CLI は `updatedInput` 非対応のため、deny-with-suggestion で提示された `rtk ...` command をそのまま再実行してください。
- `rtk gain` / `rtk gain --history` / `rtk discover` / `rtk proxy <cmd>` はそのまま実行して構いません。
