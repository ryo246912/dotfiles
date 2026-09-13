# OneCLI

[OneCLI](https://github.com/onecli/onecli) は、AI エージェントの HTTP(S) 通信を gateway に通し、
保存した credential を宛先に応じて注入するための secret vault です。この dotfiles では
**OneCLI 本体をホストの Docker で動かし、AI エージェントは devcontainer 内で使う**構成にします。
実際の secret は devcontainer に渡さず、devcontainer には agent access token を含む proxy URL
だけを渡します。

## 構成

| 項目              | 値                                                                   |
| ----------------- | -------------------------------------------------------------------- |
| Dashboard         | `http://127.0.0.1:10254`                                             |
| Gateway           | ホストの `10255`（devcontainer からは `host.docker.internal:10255`） |
| OneCLI data       | Docker volume（compose 定義は `~/.onecli/docker-compose.yml`）       |
| devcontainer 設定 | `~/.config/onecli/devcontainer.env`（mode `0600`）                   |

`devc-up-wrapper` が起動前に設定ファイルを読み、base devcontainer の `remoteEnv` へ proxy 設定を
渡します。`post-create.sh` は公開 CA を Dashboard の endpoint から取得してコンテナの system trust
store に登録するため、curl、Git、Node.js などの HTTPS 通信を gateway 経由で検証できます。

## 導入と初期設定

ホストで Docker Desktop（または Docker Engine）を起動してから実行します。

```bash
setup-onecli install
```

公式 installer により `~/.onecli/docker-compose.yml` が配置され、OneCLI と PostgreSQL が起動します。
次に `http://127.0.0.1:10254` を開き、以下を設定します。

1. **Connections** で利用する API credential を登録する。
2. **Agents** で devcontainer 用 agent を作成し、必要な credential だけを許可する。
3. 必要に応じて default agent を切り替える。

Dashboard の設定後、default agent の container config を取得します。

```bash
setup-onecli configure
```

agent token を rotation した場合も `setup-onecli configure` を再実行し、devcontainer を recreate
してください。設定ファイルには access token を含むため、共有・commit しないでください。

## 使い方

通常どおり `multi-worktree`（内部で `devc-up-wrapper` を利用）から devcontainer を起動します。
既存コンテナには環境変数や CA が反映されないため、初回設定後は recreate が必要です。

コンテナ内で確認します。

```bash
printf '%s\n' "$HTTPS_PROXY" | sed 's#//[^@]*@#//***@#'
curl https://httpbin.org/headers
```

実 credential を環境変数へ設定する必要はありません。ただし対象 SDK が認証 header を送るための
placeholder を要求する場合は、プロジェクトの devcontainer 設定で `ANTHROPIC_API_KEY=placeholder`
などを設定してください。OneCLI は Dashboard で指定した host/path と一致するリクエストだけを書き換えます。

## 運用

```bash
setup-onecli status     # container の状態
setup-onecli stop       # OneCLI を停止（volume は保持）
setup-onecli install    # 公式 image / compose 定義へ更新して再起動
```

停止中は proxy を経由する devcontainer の外向き通信が失敗します。一時的に無効化する場合は
`~/.config/onecli/devcontainer.env` を退避して devcontainer を recreate します。

## トラブルシューティング

- Dashboard が開かない: `setup-onecli status` と `docker compose -p onecli -f ~/.onecli/docker-compose.yml logs` を確認します。
- `502` / connection refused: OneCLI が起動していることと、コンテナから `curl --noproxy '*' http://host.docker.internal:10254/v1/health` が通ることを確認します。
- TLS / certificate error: devcontainer を recreate し、`/usr/local/share/ca-certificates/onecli-gateway.crt` があることを確認します。
- credential が注入されない: Dashboard の Activity、secret の host/path、default agent の権限を確認します。
- token rotation 後に `407 Proxy Authentication Required`: `setup-onecli configure` を再実行してから recreate します。

> OneCLI は通信を復号して credential を注入する gateway です。Dashboard と gateway のポートを
> 外部ネットワークへ公開せず、agent には最小限の credential のみ許可してください。
