# OneCLI

[OneCLI](https://github.com/onecli/onecli) は、AI エージェントの HTTP(S) 通信を gateway に通し、
接続先に応じた credential を注入する secret gateway です。この設定では AI エージェントと
OneCLI CLI を devcontainer 内で実行します。実際の API key は OneCLI に保存し、エージェントには
渡しません。

## 導入されるもの

`dot_config/devcontainer/mise.toml` で
[OneCLI CLI](https://github.com/onecli/onecli-cli) を導入します。devcontainer image の build 時に
mise がインストールするため、専用の install task や setup script はありません。

OneCLI CLI は `onecli run -- <agent>` の実行時に、次の処理を行います。

1. OneCLI から agent 用 proxy URL、dummy credential、gateway CA を取得する。
2. CA と agent integration を準備する。
3. proxy と dummy credential を子プロセスだけに設定して AI エージェントを起動する。

このため devcontainer 全体へ `HTTP_PROXY` などを設定する必要はありません。

## OneCLI の接続先

### OneCLI Cloud を使う場合

Dashboard で API key（`oc_...`）を発行し、ホストの `~/.zshrc.secret` に設定します。

```bash
export ONECLI_API_HOST="https://api.onecli.sh"
export ONECLI_API_KEY="oc_..."
```

### self-hosted 版を使う場合

OneCLI 本体は公式手順に従ってホストの Docker で起動します。

```bash
curl -fsSL https://onecli.sh/install | sh
```

ローカルモードでは API key は不要です。ホストの `~/.zshrc.secret` には、devcontainer から
ホストへ到達できる URL を設定します。

```bash
export ONECLI_API_HOST="http://host.docker.internal:10254"
unset ONECLI_API_KEY
```

`devcontainer.json` はこの2変数だけをホスト環境から引き継ぎます。設定後に新しい shell から
devcontainer を recreate してください。

## real API key と dummy の対応

### Anthropic / OpenAI

LLM 用 credential の dummy 値は手作業で対応表を作る必要がありません。OneCLI が agent に許可された
secret を見て、`onecli run` の子プロセスへ自動的に次の値を設定します。

| Connection        | エージェント側の設定                | gateway が注入する値                                 |
| ----------------- | ----------------------------------- | ---------------------------------------------------- |
| Anthropic API key | 手動設定不要                        | OneCLI に保存した real API key を `x-api-key` に注入 |
| OpenAI API key    | OneCLI CLI が dummy/stub を自動設定 | OneCLI に保存した real API key                       |

設定手順は次のとおりです。

1. OneCLI Dashboard の **Connections** を開く。
2. **LLM keys** から Anthropic または OpenAI を選び、real API key を保存する。
3. **Agents** で devcontainer 用 agent を作成する。
4. agent の **Credential access** で、その connection の利用を許可する。
5. policy に未反映の変更がある場合は publish する。

real API key や dummy を `.env`、`devcontainer.json`、`~/.zshrc.secret` に書かないでください。
必要な dummy credential や認証 stub は `onecli run` が起動するプロセスにだけ設定します。

### custom API

任意の API は **Connections > Custom secrets** で次を設定します。

- **Value**: real API key
- **Host pattern**: 例 `api.example.com`
- **Path pattern**: 必要な場合のみ、例 `/v1/*`
- **Inject as**: `Header`、`URL Parameter`、または `URL Path`
- **Header name / Parameter name**: 例 `Authorization` または `api_key`
- **Header value / Parameter value**: 例 `Bearer {value}`。`{value}` が real API key に置換される

たとえば `Authorization: Bearer {value}` を設定した場合、エージェントは dummy を使って通常どおり
リクエストできます。

```bash
curl -H 'Authorization: Bearer dummy' https://api.example.com/v1/resources
```

gateway は host/path が一致した通信だけを `Authorization: Bearer <real API key>` に差し替えます。
custom secret も agent の **Credential access** で明示的に許可してください。

## devcontainer での使い方

接続確認を行います。

```bash
onecli auth status
onecli agents list
onecli agents get-default
```

使用する agent を OneCLI 経由で起動します。

```bash
onecli run -- claude
onecli run -- codex
onecli run -- copilot
```

default 以外の agent を使う場合は OneCLI CLI の `run --help` で agent 指定オプションを確認します。
OneCLI を経由させずに `claude` や `codex` を直接起動した場合、proxy、CA、dummy credential は
設定されないため、OneCLI の credential injection は動作しません。

## 確認とトラブルシューティング

- `onecli auth status` が失敗する: `ONECLI_API_HOST` と、Cloud の場合は `ONECLI_API_KEY` を確認する。
- self-hosted へ接続できない: ホストで `docker compose -p onecli -f ~/.onecli/docker-compose.yml ps` を確認する。
- credential が注入されない: agent の Credential access、published policy、secret の host/path を確認する。
- API が `401` を返す: AI エージェントを直接ではなく `onecli run -- ...` で起動したか確認する。
- 詳細は Dashboard の **Activity** で、対象リクエストが gateway を通過したか確認する。

> OneCLI の API key は OneCLI 自体を操作するための credential です。`~/.zshrc.secret` を commit せず、
> agent には必要最小限の connection だけを許可してください。
