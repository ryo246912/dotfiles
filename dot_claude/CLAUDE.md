# CLAUDE.md

- 必ず日本語で回答してください。

@RTK.md

## RTK の使い方

- Bash ツールで実行する一般的な shell command は、RTK hook によって `rtk` へ自動書き換えされる前提で扱ってください。
- `Read` / `Grep` / `Glob` などの built-in tool は RTK hook を通らないため、圧縮出力が必要なときは Bash で `cat` / `head` / `tail` / `rg` / `grep` / `find` を使うか、`rtk read` / `rtk grep` / `rtk find` を直接使ってください。
- `rtk gain` / `rtk gain --history` / `rtk discover` / `rtk proxy <cmd>` はそのまま実行して構いません。
- `rtk` の導入確認が必要なときは `rtk --version` と `which rtk` を使ってください。

## Git操作ポリシー

- **ブランチ作成・切り替え**：ユーザーが行う。
- **コミット**：ユーザーが明示的に指示した場合か、作業を区切りたい場合のみ行う
  - 基本的にはコミットしない

## コミット前に確認すること（必ず実施）

- コミット前には必ず動作確認を行って動作が問題ないかを確認してください
  - コミットする際はエラーがない状態で行ってください
