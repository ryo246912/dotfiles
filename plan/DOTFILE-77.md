# DOTFILE-77 mcpの設定

## 概要

- `rulesync` を source of truth として GitHub Copilot 向け MCP と GitHub Copilot CLI 向け MCP を repo 内で管理する。
- 他 CLI に残っている MCP 設定と modular MCP は repo から削除する。
- remote MCP は project-local の GitHub Copilot (`.vscode/mcp.json`) に集約し、GitHub Copilot CLI (`~/.copilot/mcp-config.json`) には rulesync 7.23.0 で扱える stdio subset を持たせる。
- `philschmid/mcp-cli` を repo の `mise` 管理下に追加し、今回追加した Copilot MCP 設定を点検する使い方を Markdown にまとめる。

## 要件

### 機能要件

- repo root `.rulesync/mcp.json` から `.vscode/mcp.json` を生成し、issue 記載の既存 MCP に加えて `deepwiki` と `context7` を含める。
- `dot_config/rulesync/.rulesync/mcp.json` から `dot_copilot/mcp-config.json` 相当を生成し、Copilot CLI 向け stdio MCP を管理する。
- `dot_config/rulesync/.rulesync/rules/COPILOT.md` は `copilot` target に正規化し、既存の Copilot instructions generate を壊さない。
- Claude / Gemini / modular MCP の repo 内設定は削除する。
- `philschmid/mcp-cli` を `mise` から導入できるようにする。
- Copilot 向け MCP 設定の確認手順を repo 内 Markdown で参照できるようにする。
- `post_create` や repo 外 post-process は使わない。

### 非機能要件

- 変更は provided repository copy のみで完結する。
- 検証は repo 内に閉じた generate / dry-run / diff で再現できる。
- 秘密情報やローカル専用値は issue 記載の範囲を超えて増やさない。

## 実装方針

### 1. rulesync 設定の正規化

- `dot_config/rulesync/rulesync.jsonc` から無効 target を除去し、Claude / Codex / Gemini の user-scope generate を安定化する。
- `dot_config/mise/config.toml` に Copilot rules / Copilot MCP / Copilot CLI MCP の専用 task を追加する。

### 2. MCP source と generated file の追加

- repo root `.rulesync/mcp.json` を追加し、project-local GitHub Copilot 向けに remote MCP を含む完全な設定を管理する。
- `dot_config/rulesync/.rulesync/mcp.json` を追加し、GitHub Copilot CLI が受理できる stdio subset を管理する。
- generated snapshot として `.vscode/mcp.json` および `dot_copilot/mcp-config.json` を repo に保持する。

### 3. 不要設定の削除

- `dot_config/claude/claude_desktop_config_mac.json` と `dot_gemini/settings.json` から MCP を除去する。
- `dot_claude/.mcp.json`、`dot_claude/.mcp-old.json`、`dot_claude/modular-mcp.json` を削除する。
- `dot_local/bin/executable_setup-ai-tool` から Claude MCP 自動登録処理を削除する。

### 4. README / plan の更新

- `dot_config/rulesync/README.md` に source / task / generate 手順を追記する。
- `plan/DOTFILE-77.md` を実装済み方針に合わせて更新する。

### 5. mcp-cli の導入と利用ドキュメント

- `dot_config/mise/config.toml` と `dot_config/devcontainer/mise.toml` に GitHub release 版 `mcp-cli` を追加する。
- `dot_copilot/README.md` を新規追加し、`.vscode/mcp.json` と `dot_copilot/mcp-config.json` の使い分け、`mcp-cli` での一覧表示・schema 確認・call 手順を整理する。
- repo root `README.md` から新規ドキュメントへ辿れるようにする。

## 変更対象ファイル

- `.rulesync/mcp.json`
- `.vscode/mcp.json`
- `.gitignore`
- `dot_config/rulesync/.rulesync/mcp.json`
- `dot_copilot/mcp-config.json`
- `dot_config/rulesync/.rulesync/rules/COPILOT.md`
- `dot_config/rulesync/rulesync.jsonc`
- `dot_config/rulesync/README.md`
- `dot_config/mise/config.toml`
- `dot_config/devcontainer/mise.toml`
- `dot_config/claude/claude_desktop_config_mac.json`
- `dot_config/claude/claude_desktop_config_win.json`
- `dot_gemini/settings.json`
- `dot_claude/.mcp.json`
- `dot_claude/.mcp-old.json`
- `dot_claude/modular-mcp.json`
- `dot_copilot/README.md`
- `README.md`
- `dot_local/bin/executable_setup-ai-tool`

## 検証方法

- `"/Users/ryo./.local/share/mise/installs/github-dyoshikawa-rulesync/7.23.0/rulesync" generate --targets copilot --features mcp --dry-run`
- `HOME="<repo 内 temp>" "/Users/ryo./.local/share/mise/installs/github-dyoshikawa-rulesync/7.23.0/rulesync" generate --targets copilotcli --features mcp --global`
- `diff -u <temp-home>/.copilot/mcp-config.json dot_copilot/mcp-config.json`
- `rg -n "modular-mcp|\\.mcp\\.json|mcpServers" dot_claude dot_config/claude dot_gemini dot_copilot .vscode`
- `rg -n "mcp-cli" README.md dot_copilot dot_config/mise/config.toml dot_config/devcontainer/mise.toml`
- `taplo format --check dot_config/mise/config.toml dot_config/devcontainer/mise.toml`

## リスクと未解決事項

- rulesync 7.23.0 の `copilotcli` MCP は `command` を持つ stdio server 前提のため、`deepwiki` / `notion` の remote MCP は `.vscode/mcp.json` 側にのみ載せる。
- rulesync の MCP schema はトップレベル `inputs` を持たないため、issue 記載 JSON の `inputs: []` は repo 側の source / generated file に含めない。
- `mcp-cli` 自体は設定閲覧・実行の補助であり、実際の tool call 成否はローカルの `npx` / `uvx` / ネットワーク到達性に依存する。
