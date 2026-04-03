# Additional Conventions Beyond the Built-in Functions

As this project's AI coding tool, you must follow the additional conventions below, in addition to the built-in functions.

# GEMINI.md

- 必ず日本語で回答してください。

## RTK の使い方

- `run_shell_command` で実行する一般的な shell command は、Gemini hook によって `rtk` へ自動書き換えされる前提で扱ってください。
- 圧縮出力が必要なときは `rtk read` / `rtk grep` / `rtk find` を明示的に使ってください。
- `rtk gain` / `rtk gain --history` / `rtk discover` / `rtk proxy <cmd>` はそのまま実行して構いません。
- `rtk` の導入確認が必要なときは `rtk --version` と `which rtk` を使ってください。
