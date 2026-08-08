# mcpc 導入・利用ガイド

[mcpc](https://github.com/apify/mcpc) は MCP の操作をシェルコマンドとして提供する CLI client です。この dotfiles では `mcp-cli` の代わりに mcpc を使い、必要な MCP server だけを session に接続して tool を動的に検索・実行します。

## セットアップ

chezmoi を反映し、mise で mcpc と AWS MCP server の起動に使う uv をインストールします。

```bash
chezmoi apply
mise install npm:@apify/mcpc aqua:astral-sh/uv
mcpc --version
uvx --version
```

mcpc の version は mise の設定で固定しています。global npm install は不要です。

## AWS MCP の設定

同梱の [`aws-mcp.json`](./aws-mcp.json) は AWS Billing and Cost Management MCP Server と CloudWatch MCP Server の stdio 設定テンプレートです。AWS の profile と region を shell で指定してから利用します。

```bash
export AWS_PROFILE=my-profile
export AWS_REGION=ap-northeast-1
aws sso login --profile "$AWS_PROFILE" # SSO profile の場合
aws sts get-caller-identity
```

mcpc は stdio server に shell の環境変数をすべて自動継承させないため、テンプレートの `env` で `AWS_PROFILE` と `AWS_REGION` を明示的に渡しています。アクセスキーを JSON に直接書かず、AWS profile、SSO、または標準の credential provider chain を使用してください。また、profile には利用する MCP tool に必要な最小権限だけを付与してください。

自分用に server を追加・削除する場合は、このファイルをコピーして編集できます。

```bash
mkdir -p ~/.config/mcpc
cp docs/mcpc/aws-mcp.json ~/.config/mcpc/aws-mcp.json
```

`${AWS_PROFILE}` と `${AWS_REGION}` は接続時に mcpc が環境変数で置換します。

## 必要な MCP を動的に load する

### 1 server だけ接続する

設定ファイルの `:server-name` を指定すると、必要な server だけを named session として起動できます。AWS MCP はローカルの stdio server なので、信頼できる設定だけを起動してください。

```bash
mcpc connect ~/.config/mcpc/aws-mcp.json:aws-cloudwatch @aws-cloudwatch
mcpc connect ~/.config/mcpc/aws-mcp.json:aws-billing @aws-billing
```

設定内の全 server をまとめて接続する場合、stdio server は既定では除外されるため `--stdio` が必要です。

```bash
mcpc connect ~/.config/mcpc/aws-mcp.json --stdio
```

引数なしの `mcpc connect` は current directory と home directory にある標準的な MCP 設定ファイルを自動検出します。この場合もローカル server を含めるときだけ `--stdio` を付けます。

```bash
mcpc connect --stdio
```

### tool を検索して必要な schema だけ読む

接続済み session を確認し、全 tool 定義を先に context へ入れる代わりに `grep` で候補を絞ります。その後 `tools-get` で対象 tool の schema を取得し、`tools-call` で実行します。

```bash
mcpc
mcpc grep 'log|query'
mcpc @aws-cloudwatch tools-get <tool-name>
mcpc @aws-cloudwatch tools-call <tool-name> key:=value
```

複雑な引数は JSON を標準入力から渡すと shell quoting の事故を避けられます。

```bash
jq -n --arg region "$AWS_REGION" '{region: $region}' |
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
- AWS の認証エラーでは `aws sts get-caller-identity`、`AWS_PROFILE`、`AWS_REGION`、SSO session の有効期限を確認します。
- 起動中の session が不調なら `mcpc restart @<session>`、不要な状態を消す場合は `mcpc clean` を使います。
- command や引数が変わった可能性がある場合は `mcpc help <command>` と `mcpc help --skill` を正としてください。

## 関連リンク

- [apify/mcpc](https://github.com/apify/mcpc)
- [AWS Labs MCP servers](https://github.com/awslabs/mcp)
