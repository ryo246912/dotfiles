# mcpc 導入・利用ガイド

[mcpc](https://github.com/apify/mcpc) は MCP の操作をシェルコマンドとして提供する CLI client です。この dotfiles では `mcp-cli` の代わりに mcpc を使い、必要な MCP server だけを session に接続して tool を動的に検索・実行します。

## セットアップ

chezmoi を反映し、mise で mcpc、APM、AWS MCP server の起動に使う uv をインストールします。

```bash
chezmoi apply
mise install npm:@apify/mcpc github:microsoft/apm aqua:astral-sh/uv
mcpc --version
uvx --version
```

mcpc の version は mise の設定で固定しています。global npm install は不要です。

## AWS MCP の設定

AWS Billing and Cost Management MCP Server と CloudWatch MCP Server は `dot_apm/apm.yml` の `dependencies.mcp` で version を pin しています。APM が install と lockfile 管理を担当し、mcpc は APM が専用 HOME に生成した `~/.config/mcpc/apm-home/.copilot/mcp-config.json` を MCP client として読みます。

```bash
mise run apm:install
```

`mise run apm:install` は次のように役割を分けています。

- APM package は既存の agent target へ install する。
- MCP は隔離した HOME で `--only mcp --target copilot` を実行し、mcpc 専用の `~/.config/mcpc/apm-home/.copilot/mcp-config.json` だけを生成する。
- `~/.apm/apm.lock.yaml` を `dot_apm/apm.lock.yaml` へ同期する。

隔離先は実際の `~/.copilot/mcp-config.json` とは異なるため、Copilot CLI や他の agent には AWS MCP が登録されません。必要なときだけ mcpc から load できます。server を更新するときは `dot_apm/apm.yml` の `version` と、`args` にある uvx の `package@version` を同じ version に更新して `mise run apm:install` を実行し、manifest と lockfile を一緒に commit します。

生成される config は、`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`AWS_SESSION_TOKEN`、`AWS_REGION`、`AWS_DEFAULT_REGION` を mcpc の起動環境から MCP server へ転送します。credential の値や profile 名は config に保存しません。

## aws-vault profile の切り替え

`AWS_VAULT_PROFILE` を手動で export する必要はありません。利用する profile は mcpc の起動時に `aws-vault exec` で選択します。aws-vault が一時 credential と region を設定した環境内で mcpc を起動するため、その profile が自動的に AWS MCP server へ引き継がれます。

```bash
aws-vault exec my-profile -- aws sts get-caller-identity
aws-vault exec my-profile -- \
  mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

別 profile へ切り替える場合、既存 session は接続時の credential を保持しているため一度閉じ、新しい `aws-vault exec` から再接続します。

```bash
mcpc close @aws-cloudwatch
aws-vault exec another-profile -- \
  mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

同じ profile で複数の mcpc command を実行する場合は、aws-vault 配下の shell に入る方法もあります。この shell 内では plain `mcpc` が現在の `AWS_VAULT` の credential を自動利用します。

```bash
aws-vault exec my-profile -- zsh
echo "$AWS_VAULT"
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
```

アクセスキーを設定ファイルへ直接書かず、aws-vault の profile には必要な最小権限だけを付与してください。

## 必要な MCP を動的に load する

### 1 server だけ接続する

設定ファイルの `:server-name` を指定すると、必要な server だけを named session として起動できます。AWS MCP はローカルの stdio server なので、信頼できる設定だけを起動してください。

```bash
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-billing @aws-billing
```

設定内の全 server をまとめて接続する場合、stdio server は既定では除外されるため `--stdio` が必要です。

```bash
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json --stdio
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
jq -n --arg log_group '/aws/lambda/example' '{logGroupName: $log_group}' |
  mcpc --json @aws-cloudwatch tools-call <tool-name>
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
