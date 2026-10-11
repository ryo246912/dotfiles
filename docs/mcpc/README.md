# mcpc 導入・利用ガイド

[mcpc](https://github.com/apify/mcpc) は MCP の操作をシェルコマンドとして提供する CLI client です。この dotfiles では `mcp-cli` の代わりに mcpc を使い、必要な MCP server だけを session に接続して tool を動的に検索・実行します。

## セットアップ

dotfiles を反映し、mise で mcpc、APM、AWS MCP server の起動に使う uv をインストールします。

```bash
mise bootstrap dotfiles apply
mise install npm:@apify/mcpc github:microsoft/apm aqua:astral-sh/uv
mcpc --version
uvx --version
```

mcpc の version は mise の設定で固定しています。global npm install は不要です。

## AWS MCP の設定

AWS Billing and Cost Management MCP Server と CloudWatch MCP Server は `apm/apm.yml` の `dependencies.mcp` で version を pin しています。APM が install と lockfile 管理を担当し、mcpc は APM が専用 HOME に生成した `~/.local/state/mcpc/apm-home/.copilot/mcp-config.json` を MCP client として読みます。

```bash
mise run apm:install
```

`mise run apm:install` は次のように役割を分けています。

- APM package は既存の agent target へ install する。
- MCP は `apm:install-mcpc` が隔離した HOME（`${XDG_STATE_HOME:-~/.local/state}/mcpc/apm-home`）で `--only mcp --target copilot` を実行し、mcpc 専用の `~/.local/state/mcpc/apm-home/.copilot/mcp-config.json` だけを生成する。
  `~/.config` は mise の history で丸ごと track しているため、生成物は state 配下に置く。
- `~/.apm/apm.lock.yaml` を `apm/apm.lock.yaml` へ同期する。

隔離先は実際の `~/.copilot/mcp-config.json` とは異なるため、Copilot CLI や他の agent には AWS MCP が登録されません。必要なときだけ mcpc から load できます。server を更新するときは `apm/apm.yml` の `version` と、`args` にある uvx の `package@version` を同じ version に更新して `mise run apm:install` を実行し、manifest と lockfile を一緒に commit します。

生成される config は、`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`AWS_SESSION_TOKEN`、`AWS_REGION`、`AWS_DEFAULT_REGION` を mcpc の起動環境から MCP server へ転送します。credential の値や profile 名は config に保存しません。

## aws-vault profile の切り替え

`AWS_VAULT_PROFILE` を手動で export する必要はありません。利用する profile は mcpc の起動時に `aws-vault exec` で選択します。aws-vault が一時 credential と region を設定した環境内で mcpc を起動するため、その profile が自動的に AWS MCP server へ引き継がれます。`aws-vault exec` は親 shell の環境を書き換えないため、認証コマンドを先に単独実行するのではなく、mcpc をその子 process または配下の shell として起動するのが意図した使い方です。

```bash
aws-vault exec my-profile -- aws sts get-caller-identity
aws-vault exec my-profile -- \
  mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

別 profile へ切り替える場合、既存 session は接続時の credential を保持しているため一度閉じ、新しい `aws-vault exec` から再接続します。

```bash
mcpc close @aws-cloudwatch
aws-vault exec another-profile -- \
  mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

同じ profile で複数の mcpc command を実行する場合は、aws-vault 配下の shell に入る方法もあります。この shell 内では plain `mcpc` が現在の `AWS_VAULT` の credential を自動利用します。

```bash
aws-vault exec my-profile -- zsh
echo "$AWS_VAULT"
mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

アクセスキーを設定ファイルへ直接書かず、aws-vault の profile には必要な最小権限だけを付与してください。

devcontainer 内の AI agent から利用する場合は、host で `aws-vault exec <profile> -- devcontainer up ...`
として短期 credential を container の起動環境へ渡します。セットアップ、account 切り替え、期限切れ時の
再起動手順は [`docs/devcontainer.md`](../devcontainer.md#aws-vault-の認証を-container-内の-ai-agent-で使う)
を参照してください。

## Docker Sandboxes（sbx）内で使う

sandbox（[`docs/docker-sandboxes.md`](../docker-sandboxes.md)）では devcontainer と違い、AWS の credential を
VM へ渡しません。AWS MCP server は **ホスト側の stdio server として sbx の MCP gateway に登録**し、
sandbox 内の mcpc は gateway（`http://mcp-gateway.docker.internal/mcp`）へ HTTP で接続します。
credential はホストに留まり、sandbox 内の agent や mcpc からは読めません。

| 経路         | MCP server が動く場所 | mcpc の接続先                                           | AWS credential                             |
| ------------ | --------------------- | ------------------------------------------------------- | ------------------------------------------ |
| host         | host                  | `~/.local/state/mcpc/apm-home/.copilot/mcp-config.json` | `aws-vault exec` の環境を mcpc が転送      |
| devcontainer | container             | 同上（read-only mount）                                 | `remoteEnv` で container へ渡す            |
| sandbox      | host（sbx gateway）   | `http://mcp-gateway.docker.internal/mcp`                | gateway が起動する host process だけが持つ |

### 初回セットアップ（host）

mcpc は sandbox template に mise で入れています（`config/devcontainer/mise.toml`）。mcpc を追加・更新した
直後は template を作り直してください。

```bash
mise run apm:install                 # mcpc 用 MCP config を生成
mise run sandbox:build-template      # mcpc 入りの template を再ビルド
SBX_MCP_AWS_VAULT_PROFILE=my-profile mise run sandbox:mcp
```

`sandbox:mcp` は APM が生成した mcpc 用 config（`dependencies.mcp`）を読み、各 server を同じ名前
（`aws-billing` / `aws-cloudwatch`）で `sbx mcp add --command` に登録します。version は APM の manifest と
lockfile を正とし、タスク側では重複定義しません。

- `SBX_MCP_AWS_VAULT_PROFILE` を指定すると `aws-vault exec <profile> --` でラップして登録し、gateway が
  server を起動するたびにその profile の一時 credential を発行します。macOS では TTY の無い gateway からでも
  MFA 等を入力できるよう `--prompt=osascript` を付けます。
- 未指定の場合は `aws-api` と同じく host の `~/.aws`（profile / SSO）をそのまま使います。
- config の `env`（`${AWS_ACCESS_KEY_ID}` 等）は mcpc の起動環境から転送するための設定なので、
  sbx に登録した server には使いません。
- 登録済みの server はスキップします。profile を切り替えるときは登録を削除してから
  （`sbx mcp --help` 参照）、別の `SBX_MCP_AWS_VAULT_PROFILE` で再実行してください。

### 必要なときだけ load する

`SBX_AGENT_STATIC_MCP` に入れると sandbox 作成時から常時 load されます。agent の context を汚さないよう、
AWS MCP は必要になったときだけ host から稼働中の sandbox の gateway へ足します。

```bash
# host
sbx mcp load aws-cloudwatch --sandbox <sandbox-name>   # sandbox 名は sbx ls で確認
```

```bash
# sandbox 内
mcpc connect http://mcp-gateway.docker.internal/mcp @sbx   # zabrze: mcpsbx
mcpc @sbx tools-list
mcpc grep -E 'log|query'
mcpc @sbx tools-call <tool-name> key:=value
mcpc close @sbx
```

gateway は load 済みの server を 1 つの endpoint に束ねるため、session は server ごとではなく gateway に対して
1 つ（`@sbx`）です。sandbox の外で sbx に後から server を load すると、gateway は `tools/list_changed` を
通知します。mcpc 側に反映されない場合は `mcpc restart @sbx` で取り直します。

> [!NOTE]
> gateway には agent 自身も接続しているため、load した server の tool は sandbox 内の agent（claude / codex）
> からも native MCP として見えます。mcpc だけに閉じたい場合は、作業後に sandbox を作り直すか、load を
> 最小限にしてください。

### うまく繋がらないとき

- sandbox 内で `curl -sS -o /dev/null -w '%{http_code}\n' -X POST http://mcp-gateway.docker.internal/mcp` を
  実行し、gateway に到達できるか確認します。503 になる場合は sbx daemon 再起動後に gateway が
  作り直されていない可能性があるため、sandbox を `sbx stop` → `sbx-agent` で起動し直します。
- `sbx mcp ls` で server が登録済みか、`sbx policy log <sandbox-name>` でブロックされた通信が無いかを確認します。
- AWS の認証エラーは host で `aws-vault exec <profile> -- aws sts get-caller-identity` を確認します。

## 必要な MCP を動的に load する

### 1 server だけ接続する

設定ファイルの `:server-name` を指定すると、必要な server だけを named session として起動できます。以下の plain `mcpc` コマンドは `aws-vault exec <profile> -- zsh` で開始した shell 内で実行します。AWS MCP はローカルの stdio server なので、信頼できる設定だけを起動してください。

```bash
mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json:aws-billing @aws-billing
```

設定内の全 server をまとめて接続する場合、stdio server は既定では除外されるため `--stdio` が必要です。

```bash
mcpc connect ~/.local/state/mcpc/apm-home/.copilot/mcp-config.json --stdio
```

引数なしの `mcpc connect` は current directory と home directory にある標準的な MCP 設定ファイルを自動検出します。この場合もローカル server を含めるときだけ `--stdio` を付けます。

```bash
mcpc connect --stdio
```

### tool を検索して必要な schema だけ読む

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

作業後は不要な session を閉じます。次回必要になった時点で再び `connect` するのが動的 load の基本フローです。

```bash
mcpc close @aws-cloudwatch
mcpc close @aws-billing
```

## AI agent から使う

mcpc 自身が agent 向けの最新ガイドを出力します。agent の instructions に次の方針を追加すると、MCP tool を常時登録せず Bash 経由で段階的に発見できます。

```text
MCP が必要なときは `mcpc help --skill` を確認する。
必要な server だけ `mcpc connect <config>:<server> @<session>` で接続する。
`mcpc grep` → `tools-get` → `tools-call` の順に必要な tool だけを調べる。
作業後は `mcpc close @<session>` で session を閉じる。
```

機械処理では `--json` を使い、出力を `jq` などへ渡します。

## トラブルシューティング

- `mcpc connect` が失敗したら `~/.mcpc/logs/bridge-<session>.log` を確認します。
- AWS の認証エラーでは `aws-vault exec <profile> -- aws sts get-caller-identity` と aws-vault session の有効期限を確認します。session の接続後に profile を変えた場合は、対象 session を `close` してから再接続します。
- 起動中の session が不調なら `mcpc restart @<session>`、不要な状態を消す場合は `mcpc clean` を使います。
- command や引数が変わった可能性がある場合は `mcpc help <command>` と `mcpc help --skill` を正としてください。

## 関連リンク

- [apify/mcpc](https://github.com/apify/mcpc)
- [AWS Labs MCP servers](https://github.com/awslabs/mcp)
