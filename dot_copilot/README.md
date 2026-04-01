# Copilot CLI MCP と `mcp-cli` の使い方

## 目的

- GitHub Copilot CLI 向け MCP の正本は `dot_config/rulesync/exact_dot_rulesync/mcp.json.tmpl` です。
- `chezmoi apply` で `~/.config/rulesync` を復元し、apply 後の script が `rulesync` を直接実行して `~/.copilot/mcp-config.json` を生成します。
- `mcp-cli` を使うと、生成済みの Copilot CLI 向け MCP を一覧・確認・実行できます。

## 関連ファイル

| ファイル | 用途 |
| --- | --- |
| `dot_config/rulesync/exact_dot_rulesync/mcp.json.tmpl` | `~/.copilot/mcp-config.json` の source of truth |
| `~/.copilot/mcp-config.json` | `rulesync generate` が生成する runtime output |

## 収録している MCP

| Server | Type | 備考 |
| --- | --- | --- |
| `io.github.ChromeDevTools/chrome-devtools-mcp` | `stdio` | ローカル Chrome DevTools 接続 |
| `makenotion/notion-mcp-server` | `stdio` | `mcp-remote` 経由で `https://mcp.notion.com/mcp` へ接続 |
| `AWS Billing and Cost Management MCP Server` | `stdio` | `chezmoi apply` 時の `AWS_PROFILE` を利用 |
| `CloudWatch MCP Server(staging)` | `stdio` | `chezmoi apply` 時の `AWS_PROFILE` を利用 |
| `deepwiki` | `stdio` | `mcp-remote` 経由で `https://mcp.deepwiki.com/mcp` へ接続 |
| `context7` | `stdio` | `npx -y @upstash/context7-mcp@latest` |

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
chezmoi apply
```

apply 後に手動で再生成したい場合:

```sh
mise run rulesync-generate
```

直接実行する場合は以下です。

```sh
(cd ~/.config/rulesync && rulesync generate)
```

差分確認は以下を使います。

```sh
git diff -- dot_config/rulesync/exact_dot_rulesync/mcp.json.tmpl
diff -u ~/.copilot/mcp-config.json <(cd ~/.config/rulesync && rulesync generate >/dev/null 2>&1; cat ~/.copilot/mcp-config.json)
```

`AWS_PROFILE` は `chezmoi apply` 実行時の環境変数から注入されます。

```sh
export AWS_PROFILE=your-profile
chezmoi apply
```

## 基本の使い方

### 1. 設定済み server を一覧する

```sh
mcp-cli -c ~/.copilot/mcp-config.json
```

説明つきで見たい場合:

```sh
mcp-cli -c ~/.copilot/mcp-config.json -d
```

### 2. server ごとの tool を調べる

まず server を指定して利用可能な tool と schema を確認します。

```sh
mcp-cli -c ~/.copilot/mcp-config.json info context7
```

remote MCP を見る場合は以下でも確認できます。

```sh
mcp-cli -c ~/.copilot/mcp-config.json info deepwiki
mcp-cli -c ~/.copilot/mcp-config.json info makenotion/notion-mcp-server
```

tool 名まで分かったら、個別 schema を確認します。

```sh
mcp-cli -c ~/.copilot/mcp-config.json info context7 <tool-name>
```

`info <server>/<tool>` 形式でも同じです。

```sh
mcp-cli -c ~/.copilot/mcp-config.json info context7/<tool-name>
```

### 3. tool 名を絞り込む

glob で横断検索できます。

```sh
mcp-cli -c ~/.copilot/mcp-config.json grep "*search*"
```

説明つきで見たい場合:

```sh
mcp-cli -c ~/.copilot/mcp-config.json grep "*search*" -d
```

### 4. tool を実行する

短い JSON は引数でそのまま渡せます。

```sh
mcp-cli -c ~/.copilot/mcp-config.json call <server> <tool> '{"key":"value"}'
```

長い JSON や quote を含む引数は stdin の方が安全です。

```sh
cat args.json | mcp-cli -c ~/.copilot/mcp-config.json call <server> <tool>
```

heredoc でも渡せます。

```sh
mcp-cli -c ~/.copilot/mcp-config.json call <server> <tool> <<'EOF'
{"key":"value"}
EOF
```

## 注意点

- 2026-04-09 時点でも `rulesync 7.28.0` は `copilotcli` target で `command` を持つ stdio server を前提にします。
- この repo では Notion / deepwiki の remote MCP を `npx -y mcp-remote@latest <url>` として source に定義し、rulesync 単体で `~/.copilot/mcp-config.json` を生成します。
- Notion MCP は設定だけ repo に含めます。実際の利用時は Copilot CLI または `mcp-cli` 側で認可フローが走る前提です。
- `mcp-remote` は初回実行時に `npx` 経由で取得されます。ネットワーク到達性が必要です。

## トラブルシュート

- `command not found: mcp-cli`
  - `mise install ubi:philschmid/mcp-cli` を実行し、必要なら新しい shell を開き直します。
- tool call に失敗する
  - `npx` / `uvx` で各 MCP server を起動できるか、ネットワーク到達性があるかを確認します。Notion / deepwiki は `mcp-remote` の取得も必要です。
- 期待した server が出ない
  - `~/.config/rulesync/.rulesync` が存在するか確認し、必要なら `mise run rulesync-generate` を再実行します。
