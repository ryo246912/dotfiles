# DOTFILE-77 mcpの設定

## 目的とスコープ

- 2026-04-01 の最新指示に合わせ、MCP の正本を `dot_config/rulesync/.rulesync/mcp.json` に一本化し、それを GitHub Copilot CLI 用 `dot_copilot/mcp-config.json` へ同期する形だけを残す。
- repo root の GitHub Copilot 向け MCP source / generated file（`.rulesync/mcp.json`, `.vscode/mcp.json`）は削除する。
- 他 CLI 向け MCP 設定と modular MCP の削除状態を維持しつつ、`deepwiki` / `makenotion/notion-mcp-server` を含む Copilot CLI 構成と `mcp-cli` の利用ドキュメントを更新する。

## 実装方針

### 1. rulesync の正本を Copilot CLI 側へ集約する

- `dot_config/rulesync/.rulesync/mcp.json` を唯一の MCP source of truth とする。
- `dot_config/rulesync/.rulesync/mcp.json` に `deepwiki` と `makenotion/notion-mcp-server` を追加し、`dot_copilot/mcp-config.json` を source に再同期する。
- repo root の `.rulesync/mcp.json` と `.vscode/mcp.json` は削除する。

### 2. generate 導線を整理する

- `dot_local/bin/executable_rulesync-sync-copilot-mcp` を追加し、rulesync source から Copilot CLI が読む `mcp-config.json` を正規化する。
- `dot_config/mise/config.toml` の `rulesync-generate-mcp-copilotcli` task を `rulesync generate` + 正規化スクリプトの 2 段階に更新する。
- `dot_config/rulesync/README.md` と `dot_copilot/README.md` を更新し、Copilot CLI への同期手順と `mcp-cli` の使い方を現行構成へ合わせる。

### 3. rulesync の制約を repo 内で吸収する

- GitHub Copilot CLI 自体は HTTP MCP を受け付けるが、`rulesync` の `copilotcli` target は現時点で `command` を持つ stdio server しか materialize できない。
- そのため、repo では rulesync source を維持したまま、Copilot CLI 対応 field に落とし込む同期スクリプトで gap を補う。

## 変更対象ファイル

- `.rulesync/mcp.json`（削除）
- `.vscode/mcp.json`（削除）
- `dot_config/rulesync/.rulesync/mcp.json`
- `dot_copilot/mcp-config.json`
- `dot_local/bin/executable_rulesync-sync-copilot-mcp`
- `dot_config/mise/config.toml`
- `dot_config/rulesync/README.md`
- `dot_copilot/README.md`
- `plan/DOTFILE-77.md`

## 検証方法

- `git fetch origin main`
- `git merge origin/main`
- `HOME="<repo 内 temp>" XDG_CONFIG_HOME="<repo 内 temp>/.config" "/Users/ryo./.local/share/mise/installs/github-dyoshikawa-rulesync/7.23.0/rulesync" generate --targets copilotcli --features mcp --global`
- `./dot_local/bin/executable_rulesync-sync-copilot-mcp "<repo 内 temp>/.config/rulesync/.rulesync/mcp.json" "<repo 内 temp>/.copilot/mcp-config.json"`
- `diff -u <temp-home>/.copilot/mcp-config.json dot_copilot/mcp-config.json`
- `python3 -m json.tool dot_config/rulesync/.rulesync/mcp.json dot_copilot/mcp-config.json`
- `python3 - <<'PY' ... deepwiki / notion / context7 / aws keys を検証 ... PY`
- `rg -n "mcp|modular-mcp|mcpServers|\\.mcp\\.json" .`
- `git diff --check`

## リスクと未解決事項

- `rulesync 7.23.0` 単体では引き続き `copilotcli` target の HTTP MCP を出力できない。将来 `rulesync` 側が対応したら、正規化スクリプトは簡素化または削除できる。
- `rulesync` の MCP schema はトップレベル `inputs` を持たないため、issue 記載 JSON の `inputs: []` は source / generated file に含めない。
- `mcp-cli` は設定閲覧・実行の補助であり、実際の tool call 成否はローカルの `npx` / `uvx` / ネットワーク到達性に依存する。
