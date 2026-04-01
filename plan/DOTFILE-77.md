# DOTFILE-77 mcpの設定

## 目的とスコープ

- GitHub Copilot CLI 向け MCP を `dot_config/rulesync/.rulesync/mcp.json` に一本化し、`rulesync generate --targets copilotcli --features mcp --global` だけで `dot_copilot/mcp-config.json` を再生成できるようにする。
- 他 CLI 向け MCP 設定と modular MCP の削除状態を維持する。
- issue で求められている Chrome DevTools / Notion / AWS Billing / CloudWatch / deepwiki / context7 を Copilot CLI で使える構成に保つ。

## 実装方針

### 1. rulesync 単体で materialize できる source に寄せる

- `rulesync 7.23.0` の `copilotcli` target は `command` を持つ stdio server 前提なので、Notion と deepwiki は `npx -y mcp-remote@latest <url>` の stdio wrapper として source に定義する。
- AWS 系、Chrome DevTools、context7 はそのまま stdio server として保持する。

### 2. custom script を削除する

- `dot_local/bin/executable_rulesync-sync-copilot-mcp` を削除する。
- `dot_config/mise/config.toml` の `rulesync-generate-mcp-copilotcli` task は pure `rulesync generate` の 1 段階に戻す。

### 3. ドキュメントを現行構成へ揃える

- `dot_config/rulesync/README.md` と `dot_copilot/README.md` から正規化スクリプト前提を外し、remote MCP を stdio wrapper として持つ理由と再生成方法を記載する。

## 変更対象ファイル

- `dot_config/rulesync/.rulesync/mcp.json`
- `dot_copilot/mcp-config.json`
- `dot_config/mise/config.toml`
- `dot_config/rulesync/README.md`
- `dot_copilot/README.md`
- `dot_local/bin/executable_rulesync-sync-copilot-mcp`（削除）
- `plan/DOTFILE-77.md`

## 検証方法

- `git fetch origin main`
- `git merge origin/main`
- `HOME="<repo 内 temp>" XDG_CONFIG_HOME="<repo 内 temp>/.config" "/Users/ryo./.local/share/mise/installs/github-dyoshikawa-rulesync/7.23.0/rulesync" generate --targets copilotcli --features mcp --global`
- `diff -u <temp-home>/.copilot/mcp-config.json dot_copilot/mcp-config.json`
- `python3 -m json.tool dot_config/rulesync/.rulesync/mcp.json`
- `python3 -m json.tool dot_copilot/mcp-config.json`
- `python3 - <<'PY' ... Chrome / Notion / AWS / CloudWatch / deepwiki / context7 の key と command/url を検証 ... PY`
- `rg -n "mcpServers|modular-mcp|\\.mcp\\.json" dot_claude dot_config/claude dot_gemini`
- `git diff --check`

## リスクと未解決事項

- `mcp-remote` は `npx` 経由で初回取得されるため、Notion / deepwiki の利用時はネットワーク到達性が必要。
- `rulesync` が将来 `copilotcli` target で HTTP MCP をそのまま出力できるようになったら、stdio wrapper は不要になる可能性がある。
- `mcp-cli` は設定閲覧・実行の補助であり、実際の tool call 成否はローカルの `npx` / `uvx` / ネットワーク到達性に依存する。
