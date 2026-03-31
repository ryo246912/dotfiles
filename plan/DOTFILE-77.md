# DOTFILE-77 mcpの設定

## 目的とスコープ

- 2026-03-31 の最新指示に合わせ、MCP の正本を `dot_config/rulesync/.rulesync/mcp.json` に一本化し、それを GitHub Copilot CLI 用 `dot_copilot/mcp-config.json` へ同期する形だけを残す。
- repo root の GitHub Copilot 向け MCP source / generated file（`.rulesync/mcp.json`, `.vscode/mcp.json`）は削除する。
- 他 CLI 向け MCP 設定と modular MCP の削除状態を維持しつつ、`mcp-cli` の導入と利用ドキュメントを更新する。

## 実装方針

### 1. rulesync の正本を Copilot CLI 側へ集約する

- `dot_config/rulesync/.rulesync/mcp.json` を唯一の MCP source of truth とする。
- `dot_copilot/mcp-config.json` を source に再同期し、現在の AWS profile 値を含む generated snapshot へ揃える。
- repo root の `.rulesync/mcp.json` と `.vscode/mcp.json` は削除する。

### 2. generate 導線を整理する

- `dot_config/mise/config.toml` から project-local Copilot MCP task を削除し、`rulesync-generate-mcp-copilotcli` だけを残す。
- `dot_config/rulesync/README.md` と `dot_copilot/README.md` を更新し、Copilot CLI への同期手順と `mcp-cli` の使い方を現行構成へ合わせる。

### 3. 制約を blocker として明文化する

- GitHub Copilot CLI 自体は HTTP MCP を受け付けるが、`rulesync` の `copilotcli` target は現時点で `command` を持つ stdio server しか materialize できない。
- `rulesync 7.23.0` と `rulesync 7.25.0` の両方でこの制約を確認し、`deepwiki` / `makenotion/notion-mcp-server` を repo 内の rulesync-only sync に乗せられないことを記録する。

## 変更対象ファイル

- `.rulesync/mcp.json`（削除）
- `.vscode/mcp.json`（削除）
- `dot_config/rulesync/.rulesync/mcp.json`
- `dot_copilot/mcp-config.json`
- `dot_config/mise/config.toml`
- `dot_config/rulesync/README.md`
- `dot_copilot/README.md`
- `plan/DOTFILE-77.md`

## 検証方法

- `git fetch origin main`
- `git merge origin/main`
- `HOME="<repo 内 temp>" XDG_CONFIG_HOME="<repo 内 temp>/.config" "/Users/ryo./.local/share/mise/installs/github-dyoshikawa-rulesync/7.23.0/rulesync" generate --targets copilotcli --features mcp --global`
- `diff -u <temp-home>/.copilot/mcp-config.json dot_copilot/mcp-config.json`
- `python3 -m json.tool dot_config/rulesync/.rulesync/mcp.json dot_copilot/mcp-config.json`
- `rg -n "mcp|modular-mcp|mcpServers|\\.mcp\\.json" .`
- `git diff --check`

## リスクと未解決事項

- 2026-03-31 時点で `rulesync 7.23.0` と `7.25.0` はどちらも `copilotcli` target で HTTP MCP を出力できない。issue 要件の `deepwiki` / `notion` は repo-only / rulesync-only では同期できない。
- `rulesync` の MCP schema はトップレベル `inputs` を持たないため、issue 記載 JSON の `inputs: []` は source / generated file に含めない。
- `mcp-cli` は設定閲覧・実行の補助であり、実際の tool call 成否はローカルの `npx` / `uvx` / ネットワーク到達性に依存する。
