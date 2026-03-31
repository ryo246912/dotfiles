# Copilot CLI MCP と `mcp-cli` の使い方

## 目的

- このディレクトリでは GitHub Copilot CLI 向けの `mcp-config.json` を管理します。
- 正本は `dot_config/rulesync/.rulesync/mcp.json` です。
- `mcp-cli` を使うと、repo で管理している Copilot CLI 向け MCP を一覧・確認・実行できます。

## 関連ファイル

| ファイル | 用途 |
| --- | --- |
| `dot_config/rulesync/.rulesync/mcp.json` | `dot_copilot/mcp-config.json` の source of truth |
| `dot_copilot/mcp-config.json` | `~/.copilot/mcp-config.json` に同期する generated snapshot |

## インストール

repo root で通常どおり `mise install` を実行すれば `mcp-cli` も入ります。

```sh
mise install --jobs=2
```

`mcp-cli` だけを入れたい場合は以下でも構いません。

```sh
mise install ubi:philschmid/mcp-cli
```

この repo では GitHub release の単体 binary を使うため、`ubi:philschmid/mcp-cli = "0.3.0"` を `mise` 設定に固定しています。

## 設定を再生成する

Copilot CLI 用 MCP を編集したら、`rulesync` の生成結果を更新します。

```sh
mise run rulesync-generate-mcp-copilotcli
```

差分確認は以下を使います。

```sh
git diff -- dot_copilot/mcp-config.json dot_config/rulesync/.rulesync/mcp.json
```

## 基本の使い方

### 1. 設定済み server を一覧する

```sh
mcp-cli -c dot_copilot/mcp-config.json
```

説明つきで見たい場合:

```sh
mcp-cli -c dot_copilot/mcp-config.json -d
```

### 2. server ごとの tool を調べる

まず server を指定して利用可能な tool と schema を確認します。

```sh
mcp-cli -c dot_copilot/mcp-config.json info context7
```

tool 名まで分かったら、個別 schema を確認します。

```sh
mcp-cli -c dot_copilot/mcp-config.json info context7 <tool-name>
```

`info <server>/<tool>` 形式でも同じです。

```sh
mcp-cli -c dot_copilot/mcp-config.json info context7/<tool-name>
```

### 3. tool 名を絞り込む

glob で横断検索できます。

```sh
mcp-cli -c dot_copilot/mcp-config.json grep "*search*"
```

説明つきで見たい場合:

```sh
mcp-cli -c dot_copilot/mcp-config.json grep "*search*" -d
```

### 4. tool を実行する

短い JSON は引数でそのまま渡せます。

```sh
mcp-cli -c dot_copilot/mcp-config.json call <server> <tool> '{"key":"value"}'
```

長い JSON や quote を含む引数は stdin の方が安全です。

```sh
cat args.json | mcp-cli -c dot_copilot/mcp-config.json call <server> <tool>
```

heredoc でも渡せます。

```sh
mcp-cli -c dot_copilot/mcp-config.json call <server> <tool> <<'EOF'
{"key":"value"}
EOF
```

## 注意点

- 2026-03-31 時点で `rulesync 7.23.0` と `rulesync 7.25.0` の両方を検証したが、`copilotcli` target で同期できるのは `command` を持つ `stdio` server のみです。
- GitHub Copilot CLI 自体は HTTP MCP を受け付けるが、現行 `rulesync` では `deepwiki` や `makenotion/notion-mcp-server` のような remote MCP を `dot_copilot/mcp-config.json` へ materialize できません。
- そのため、この repo で同期できるのは `chrome-devtools`、AWS 系、`context7` のような stdio server に限られます。

## トラブルシュート

- `command not found: mcp-cli`
  - `mise install ubi:philschmid/mcp-cli` を実行し、必要なら新しい shell を開き直します。
- tool call に失敗する
  - `npx` / `uvx` で各 MCP server を起動できるか、ネットワーク到達性があるかを確認します。
- 期待した server が出ない
  - `mise run rulesync-generate-mcp-copilotcli` 実行後に `git diff` で生成結果を確認します。
