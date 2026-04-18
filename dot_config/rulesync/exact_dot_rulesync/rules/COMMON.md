---
root: true
targets:
  - claudecode
  - codexcli
  - geminicli
  - copilot
  - copilotcli
globs:
  - "**/*"
---

- 必ず日本語で回答してください。

## コマンド実行について

- devcontainer 内でのテスト・ビルド・パッケージインストールなどのコマンドはユーザーがホスト側で実行する
- 上記のようなコマンドは提案するにとどめ、Bash ツールで実行しない（明示的に依頼された場合を除く）
