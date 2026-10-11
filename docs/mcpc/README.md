# mcpc 導入・利用ガイド

[mcpc](https://github.com/apify/mcpc) は MCP の操作をシェルコマンドとして提供する CLI client です。この dotfiles では `mcp-cli` の代わりに mcpc を使い、必要な MCP server だけを session に接続して tool を動的に検索・実行します。

## なぜ mcpc を使うのか（コンテキスト節約の仕組み）

agent（Claude Code など）の native MCP に server を登録すると、起動時に全 tool の定義（名前・説明・引数の JSON Schema）が system prompt に入り、使わない会話でもコンテキストを消費し続けます。

mcpc では MCP server を agent の設定に登録しません。

1. MCP server の定義は agent が読まない mcpc 専用の config（`~/.config/mcpc/apm-home/.copilot/mcp-config.json`）にだけ置く。agent は起動時に何も読み込まない。
2. 必要になったら agent が Bash で `mcpc connect <config>:<server> @<session>` を実行する。mcpc の bridge process が server との接続を保持し、agent にはコマンドの出力だけが返る。
3. `mcpc grep` で tool 名を探し、`tools-get` で使う tool の schema だけを読み、`tools-call` で実行する。コンテキストに入るのはこの出力だけ。
4. 作業後は `mcpc close @<session>` で閉じる。

## 管理している MCP server

`apm/apm.yml` の `dependencies.mcp` で定義と version を pin しています（追加・更新もここで行う）。

| server            | 用途                               | 実体（pin）                                  | 認証                                                        |
| ----------------- | ---------------------------------- | -------------------------------------------- | ----------------------------------------------------------- |
| `aws-api`         | AWS CLI 相当の API 呼び出し        | `awslabs.aws-api-mcp-server`（uvx）          | `aws-vault exec` が渡す一時 credential                      |
| `aws-billing`     | 請求・コスト                       | `awslabs.billing-cost-management-mcp-server` | 同上                                                        |
| `aws-cloudwatch`  | CloudWatch Logs / Metrics / Alarms | `awslabs.cloudwatch-mcp-server`              | 同上                                                        |
| `notion`          | Notion（remote MCP）               | `mcp-remote` → `https://mcp.notion.com/mcp`  | 初回にブラウザで OAuth。token は `~/.mcp-auth`              |
| `slack`           | Slack                              | `slack-mcp-server`（korotovsky）             | `SLACK_MCP_XOXP_TOKEN`（fnox の work profile）              |
| `metabase`        | Metabase                           | `@cognitionai/metabase-mcp-server`           | `METABASE_URL` / `METABASE_API_KEY`（fnox の work profile） |
| `chrome-devtools` | host の Chrome（`localhost:9222`） | `chrome-devtools-mcp`                        | 不要（remote debugging を有効にした Chrome を起動しておく） |

credential の値や profile 名は config に書きません。config の `env` は `${VAR}` で mcpc の起動環境から server へ転送します（mcpc は stdio server に最小限の環境変数しか渡さないため）。

## セットアップ

dotfiles を反映し、mise で mcpc、APM、server の起動に使う uv / node をインストールしてから、mcpc 用 config を生成します。

```bash
mise bootstrap dotfiles apply
mise install
mise run apm:install
```

`mise run apm:install` は次のように役割を分けています。

- APM package は既存の agent target へ install する。
- MCP は `apm:install-mcpc` が隔離した HOME（`~/.config/mcpc/apm-home`）で `--only mcp --target copilot` を実行し、mcpc 専用の config を生成する。実際の `~/.copilot/mcp-config.json` とは別の場所なので、Copilot CLI や他の agent には登録されない。
- 同時に sandbox 用の config（`~/.config/mcpc/sandbox/mcp-config.json`。URL だけ）も生成する（[後述](#docker-sandboxessbx内で使う)）。
- `~/.apm/apm.lock.yaml` を `apm/apm.lock.yaml` へ同期する。

server を更新するときは `apm/apm.yml` の `version` と、`args` にある `package@version` を同じ version に更新して `mise run apm:install` を実行し、manifest と lockfile を一緒に commit します。

## work3 で使う（認証情報の渡し方）

AWS は `aws-vault exec`、Slack / Metabase は fnox の work profile（`HOST_ENV` に work ロールを含むホストで有効。[`docs/fnox.md`](../fnox.md)）から環境変数として渡します。Slack / Metabase の secret は `config/fnox/config.work.toml` の `[profiles.work.secrets]` に `env = "exec"` で登録してください（同ファイルにコメントアウトした例があります）。

`aws-vault exec` / `fnox exec` は親 shell の環境を書き換えないため、mcpc をその子 process として起動します。何度も実行するなら配下の shell に入ると楽です。

```bash
aws-vault exec my-profile -- fnox exec --profile work -- zsh
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:slack @slack
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

session は接続時の credential を保持するため、profile を切り替えるときや期限が切れたときは `mcpc close` してから新しい `aws-vault exec` の配下で接続し直します。aws-vault の profile には必要な最小権限だけを付与してください。

## Docker Sandboxes（sbx）内で使う

sandbox（[`docs/docker-sandboxes.md`](../docker-sandboxes.md)）では credential を VM へ渡しません。MCP server は **host で動かし**、mcp-proxy で HTTP として公開します。sandbox 内の mcpc は URL だけを書いた config で接続します。

```
[host]    aws-vault exec … -- fnox exec --profile work -- mise run sandbox:mcp aws-cloudwatch slack
            └─ mcp-proxy（127.0.0.1:8931）─ stdio MCP server
[sandbox] mcpc connect "$MCPC_SANDBOX_CONFIG:aws-cloudwatch" @aws-cloudwatch
            └─ http://host.docker.internal:8931/servers/aws-cloudwatch/mcp
```

| 経路         | MCP server が動く場所 | mcpc の config                                                     | credential                        |
| ------------ | --------------------- | ------------------------------------------------------------------ | --------------------------------- |
| host         | host                  | `~/.config/mcpc/apm-home/.copilot/mcp-config.json`                 | `aws-vault` / `fnox` の環境を転送 |
| devcontainer | container             | 同上（read-only mount）                                            | `remoteEnv` で container へ渡す   |
| sandbox      | host（mcp-proxy）     | `$MCPC_SANDBOX_CONFIG`（`~/.config/mcpc/sandbox/mcp-config.json`） | host の proxy process だけが持つ  |

sbx の MCP gateway（`sbx mcp` / `--static-mcp`）は使いません。gateway に載せた tool は sandbox 内の agent にも native MCP として常に見えてしまい、上記のコンテキスト節約が成立しないためです。

### 初回だけ

mcpc は sandbox template に mise で入れています（`config/devcontainer/mise.toml`）。template を作り直し、sandbox 用 config を生成してから sandbox を作ります。`sbx-agent` は config があれば read-only でマウントし、`MCPC_SANDBOX_CONFIG` にそのパスを入れます。config を生成する前に作った sandbox は作り直してください。

```bash
mise run apm:install
mise run sandbox:build-template
```

### 使うとき

host で使う server だけを指定して proxy を前面で起動し、作業が終わったら Ctrl-C で止めます。mcp-proxy は指定した server を起動時にすべて立ち上げ、1 つでも失敗すると止まるため、必要なものだけを渡します。引数なしで実行すると server の一覧を表示します。

```bash
# host（tmux の別 pane など）
aws-vault exec my-profile -- fnox exec --profile work -- mise run sandbox:mcp aws-cloudwatch slack
```

```bash
# sandbox 内
mcpc connect "$MCPC_SANDBOX_CONFIG:aws-cloudwatch" @aws-cloudwatch
mcpc grep -E 'log|query'
mcpc @aws-cloudwatch tools-get describe_log_groups
mcpc close @aws-cloudwatch
```

- `sandbox:mcp` は config の `env`（`${VAR}`）を外し、`--pass-environment` で aws-vault / fnox が設定した proxy の環境をそのまま server へ渡します（mcp-proxy は `${VAR}` を展開しないため）。
- `localhost:8931` を network policy に追加します（sbx のプロキシは `host.docker.internal` を host の localhost へ転送するため）。ポートは `MCPC_PROXY_PORT` で変えられますが、変えたら `mise run apm:install` で sandbox 用 config も作り直してください。
- proxy に認証はありません。127.0.0.1 にだけ bind しますが、policy を許可した sandbox からは呼べるので、使う間だけ起動してください。
- Notion の OAuth は proxy の起動時に host のブラウザで行います。chrome-devtools は host の Chrome に繋がります。

### うまく繋がらないとき

- host で `curl -s 127.0.0.1:8931/status` を実行し、proxy と server が起動しているか確認します。
- sandbox 内で `curl -s http://host.docker.internal:8931/status` が失敗する場合は `sbx policy log <sandbox-name>` でブロックされていないか確認します。
- `echo "$MCPC_SANDBOX_CONFIG"` が空なら、config 生成前に作った sandbox です。作り直してください。

## devcontainer 内で使う

devcontainer では server を container 内で動かします。host で `aws-vault exec <profile> -- devcontainer up ...` として短期 credential を container の起動環境へ渡します。セットアップ、account 切り替え、期限切れ時の再起動手順は [`docs/devcontainer.md`](../devcontainer.md#aws-vault-の認証を-container-内の-ai-agent-で使う) を参照してください。Slack / Metabase の token は devcontainer へは渡していません。また `chrome-devtools` の `localhost:9222` は container 自身を指すため、devcontainer からは host の Chrome に繋がりません（host か sandbox の `sandbox:mcp` 経由で使ってください）。

## tool を検索して必要な schema だけ読む

接続済み session を確認し、全 tool 定義を先に context へ入れる代わりに `grep` で候補を絞ります。その後 `tools-get` で対象 tool の schema を取得し、`tools-call` で実行します。

```bash
mcpc
mcpc grep -E 'log|query'
mcpc @aws-cloudwatch tools-get <tool-name>
mcpc @aws-cloudwatch tools-call <tool-name> key:=value
```

複雑な引数は JSON を標準入力から渡すと shell quoting の事故を避けられます。

```bash
jq -n --arg prefix '/aws/lambda/' '{log_group_name_prefix: $prefix, max_items: 20}' |
  mcpc --json @aws-cloudwatch tools-call describe_log_groups
```

設定内の全 server をまとめて接続する場合、stdio server は既定では除外されるため `--stdio` が必要です（必要な server だけを接続するのが基本です）。

```bash
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json --stdio
```

## AI agent から使う

mcpc 自身が agent 向けの最新ガイドを出力します。agent の instructions に次の方針を追加すると、MCP tool を常時登録せず Bash 経由で段階的に発見できます。

```text
MCP が必要なときは `mcpc help --skill` を確認する。
必要な server だけ `mcpc connect <config>:<server> @<session>` で接続する
（sandbox 内では <config> に "$MCPC_SANDBOX_CONFIG" を使う）。
`mcpc grep` → `tools-get` → `tools-call` の順に必要な tool だけを調べる。
作業後は `mcpc close @<session>` で session を閉じる。
```

機械処理では `--json` を使い、出力を `jq` などへ渡します。

## トラブルシューティング

- `mcpc connect` が失敗したら `~/.mcpc/logs/bridge-<session>.log` を確認します。
- AWS の認証エラーでは `aws-vault exec <profile> -- aws sts get-caller-identity` と aws-vault session の有効期限を確認します。
- Slack / Metabase の認証エラーでは `fnox exec --profile work -- env | grep -c '^SLACK_MCP_XOXP_TOKEN='` などで変数が渡っているか（値は表示しない）を確認します。
- 起動中の session が不調なら `mcpc restart @<session>`、不要な状態を消す場合は `mcpc clean` を使います。
- command や引数が変わった可能性がある場合は `mcpc help <command>` と `mcpc help --skill` を正としてください。

## 関連リンク

- [apify/mcpc](https://github.com/apify/mcpc)
- [sparfenyuk/mcp-proxy](https://github.com/sparfenyuk/mcp-proxy)
- [AWS Labs MCP servers](https://github.com/awslabs/mcp)
- [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server)
- [@cognitionai/metabase-mcp-server](https://www.npmjs.com/package/@cognitionai/metabase-mcp-server)
