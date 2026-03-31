# Copilot MCP と `mcp-cli` の使い方

## 目的

- このディレクトリでは GitHub Copilot CLI 向けの `mcp-config.json` を管理します。
- project-local の GitHub Copilot 向け remote MCP は repo root の `.vscode/mcp.json` にあります。
- `mcp-cli` を使うと、どちらの設定も CLI から一覧・schema・tool call を確認できます。

## 関連ファイル

| ファイル | 用途 |
| --- | --- |
| `.vscode/mcp.json` | GitHub Copilot 向けの project-local MCP。remote MCP を含む完全版 |
| `dot_copilot/mcp-config.json` | GitHub Copilot CLI 向けの user-scope MCP。`stdio` subset |
| `.rulesync/mcp.json` | `.vscode/mcp.json` の source of truth |
| `dot_config/rulesync/.rulesync/mcp.json` | `dot_copilot/mcp-config.json` の source of truth |

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

Copilot 用 MCP を編集したら、先に rulesync の生成結果を更新します。

```sh
mise run rulesync-generate-mcp-copilot
mise run rulesync-generate-mcp-copilotcli
```

差分確認は以下を使います。

```sh
git diff -- .vscode/mcp.json dot_copilot/mcp-config.json dot_config/rulesync .rulesync/mcp.json
```

## 基本の使い方

### 1. GitHub Copilot 向け remote MCP を一覧する

`.vscode/mcp.json` は `notion` と `deepwiki` のような remote MCP を含む完全版です。

```sh
mcp-cli -c .vscode/mcp.json
```

説明つきで見たい場合:

```sh
mcp-cli -c .vscode/mcp.json -d
```

### 2. Copilot CLI 向け stdio subset を一覧する

`dot_copilot/mcp-config.json` は GitHub Copilot CLI 向けの subset です。

```sh
mcp-cli -c dot_copilot/mcp-config.json
```

### 3. server ごとの tool を調べる

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

### 4. tool 名を絞り込む

glob で横断検索できます。

```sh
mcp-cli -c .vscode/mcp.json grep "*search*"
```

説明つきで見たい場合:

```sh
mcp-cli -c .vscode/mcp.json grep "*search*" -d
```

### 5. tool を実行する

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

## この repo での使い分け

- `deepwiki` や `makenotion/notion-mcp-server` を確認したいときは `.vscode/mcp.json` を使います。
- `GitHub Copilot CLI` と同じ入力集合で確認したいときは `dot_copilot/mcp-config.json` を使います。
- `copilotcli` は rulesync 7.23.0 の都合で `stdio` server のみ扱うため、remote MCP は `dot_copilot/mcp-config.json` には入りません。

## トラブルシュート

- `command not found: mcp-cli`
  - `mise install ubi:philschmid/mcp-cli` を実行し、必要なら新しい shell を開き直します。
- tool call に失敗する
  - `npx` / `uvx` で各 MCP server を起動できるか、ネットワーク到達性があるかを確認します。
- 期待した server が出ない
  - `mise run rulesync-generate-mcp-copilot` または `mise run rulesync-generate-mcp-copilotcli` 実行後に `git diff` で生成結果を確認します。
