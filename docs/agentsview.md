# agentsview pg-sync

複数端末のセッション情報を Fly.io 上の PostgreSQL に集約し、read-only Web UI で参照する構成。

## 構成

```
PC-A (hostname: mac-work)          PC-B (hostname: mac-home)
└── ~/.agentsview/*.sqlite          └── ~/.agentsview/*.sqlite
        ↓ mise run agentsview:pg:push       ↓ mise run agentsview:pg:push
        └──────────────────────────────────┘
                        ↓
        Fly.io psgl (PostgreSQL / 既存 Atuin 共用)
        └── agentsview schema
                ├── sessions (machine=mac-work)
                └── sessions (machine=mac-home)
                        ↓ 読み取り
        Fly.io ryo-agentsview
        └── agentsview pg serve  →  https://ryo-agentsview.fly.dev
```

## 初回セットアップ

### 1. Fly app を作成

```sh
flyctl apps create ryo-agentsview
```

### 2. PostgreSQL role を分ける

公開 viewer と local push は別の DB role を使う。

- `agentsview_read`: Fly app の `pg serve` 用。通常運用は `SELECT` のみ。
- `agentsview_push_mac`: ローカル PC からの `agentsview pg push` 用。`agentsview` schema だけに DML 権限を持つ。
- `agentsview_owner`: 初回 schema 作成・migration 用。通常の app / local push では使わない。

`psgl` に接続して、secret 値は手元の password manager に保管する。

mise task で実行する場合:

```sh
export AGENTSVIEW_ADMIN_PG_PASSWORD='<postgres-admin-pass>'
export AGENTSVIEW_OWNER_PASSWORD='<owner-pass>'
export AGENTSVIEW_PUSH_PASSWORD='<push-pass>'
export AGENTSVIEW_READ_PASSWORD='<read-pass>'

mise run agentsview:setup:db-roles
```

task は `dot_config/mise/tasks/agentsview.toml` の `agentsview:setup:db-roles` で定義している。`AGENTSVIEW_ADMIN_PG_USER`、`AGENTSVIEW_ADMIN_PG_DATABASE`、`AGENTSVIEW_PG_APP` は必要に応じて上書きできる。

> このタスクは `flyctl proxy` を一時起動し、`psql`（libpq client）で接続する。admin password は `PGPASSWORD`（環境変数）で渡して process 引数には出さず、`psql -v ON_ERROR_STOP=1` で途中の DDL/GRANT 失敗も検出する。実行には `psql` が必要（無い場合は `mise use -g postgres` 等で導入する）。

> 上記の必須 env（`AGENTSVIEW_*_PASSWORD` や各 URL / token）は、`export` せずに `mise run` した場合、その場で（入力を伏せて）1 つずつ尋ねられる。事前に `export` しておけばプロンプトは出ない。値が無いまま（非 TTY の CI 等）は `Set <VAR>` でエラー停止する。この対話入力は `agentsview:setup:migrate` / `agentsview:fly:secrets` / `agentsview:pg:status` / `agentsview:pg:push` でも同様。task 側で `shell = "bash -c"` と `interactive = true` を指定して端末に直結している。

> 下記の SQL は概念的な内容の抜粋。実際の task は `CREATE ROLE ... / ALTER ROLE ...` を存在チェック付きで冪等に実行し、role 属性（`NOSUPERUSER` 等）も毎回正規化するため、再セットアップや password rotation でも重複エラーにならない。

実行される SQL の内容:

```sql
CREATE ROLE agentsview_owner LOGIN PASSWORD '<owner-pass>';
CREATE ROLE agentsview_push_mac LOGIN PASSWORD '<push-pass>';
CREATE ROLE agentsview_read LOGIN PASSWORD '<read-pass>';

CREATE SCHEMA IF NOT EXISTS agentsview AUTHORIZATION agentsview_owner;

GRANT USAGE ON SCHEMA agentsview TO agentsview_read;
GRANT USAGE ON SCHEMA agentsview TO agentsview_push_mac;

GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push_mac;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push_mac;

ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO agentsview_push_mac;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO agentsview_push_mac;
```

既存テーブルの owner が `agentsview_owner` ではない場合、default privileges は新規作成分に効かない。その場合は migration 後に上記の `GRANT ... ON ALL TABLES` / `GRANT ... ON ALL SEQUENCES` を再実行する。

初回 schema 作成と AgentsView upgrade 後の migration は `agentsview_owner` role で実行する。通常の app / local push では owner role を使わない。
`agentsview:setup:migrate` task は `flyctl proxy` を一時起動し、migration 後に proxy を停止する。`AGENTSVIEW_MIGRATION_PROJECTS` を設定すると小さい project だけで初回 migration を通せる。

```sh
export AGENTSVIEW_OWNER_PROXY_PG_URL='postgres://agentsview_owner:<owner-pass>@127.0.0.1:15432/ryo_shellhistory?sslmode=disable'
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'

mise run agentsview:setup:migrate
```

migration 後に `GRANT ... ON ALL TABLES` / `GRANT ... ON ALL SEQUENCES` を再実行してから、local push 用の URL を `agentsview_push_mac` role に戻す。

### 3. app secrets を設定

Fly app は公開 URL で参照されるが、`require_auth = true` と bearer token で API を閉じる。PostgreSQL 接続は `agentsview_read` role を使い、公開 viewer から DB へ書き込めないようにする。

mise task で token を生成し、password manager に保存する。

```sh
mise run agentsview:fly:tokens
```

保存済み token と read-only DB URL を使って Fly secrets を設定する。

```sh
export AGENTSVIEW_AUTH_TOKEN='<saved-auth-token>'
export AGENTSVIEW_CURSOR_SECRET='<saved-cursor-secret>'
export AGENTSVIEW_READ_PG_URL='postgres://agentsview_read:<read-pass>@psgl.flycast:5432/ryo_shellhistory?sslmode=disable'

mise run agentsview:fly:secrets
```

task は `dot_config/mise/tasks/agentsview.toml` の `agentsview:fly:tokens` / `agentsview:fly:secrets` で定義している。

手動で実行する場合:

```sh
AUTH=$(openssl rand -base64 32)
CURSOR=$(openssl rand -base64 32)

CONFIG_B64=$(
  printf 'public_url = "https://ryo-agentsview.fly.dev"\nrequire_auth = true\nauth_token = "%s"\ncursor_secret = "%s"\n\n[pg]\nallow_insecure = true\n' "$AUTH" "$CURSOR" \
  | base64 | tr -d '\n'
)

flyctl secrets set -a ryo-agentsview \
  AGENTSVIEW_PG_URL='postgres://agentsview_read:<read-pass>@psgl.flycast:5432/ryo_shellhistory?sslmode=disable' \
  AGENTSVIEW_CONFIG_TOML="$CONFIG_B64"

echo "Bearer token: $AUTH"  # 保管しておく
```

> `AGENTSVIEW_CONFIG_TOML` は Fly.io の `[[files]]` で `/data/config.toml` に展開されるため、secret には TOML を base64 encode した値を設定する。
> `public_url` は公開 URL / origin validation 用に入れる。
> `require_auth` / `auth_token` は env var 非対応のため config.toml 経由で渡す。
> `cursor_secret` は起動時の自動生成・config 書き戻しを避けるため、初回から明示する。
> `agentsview_read` role で schema migration が必要になった場合、`pg serve` は migration を skip して compatibility check に落ちる。AgentsView upgrade 後に migration が必要なときだけ、手元から `agentsview_owner` role で migration / push を実行し、完了後に app は read-only role のまま運用する。

> **PG 接続先の確認方法:** password を端末履歴・記録・画面共有へ露出させないため、`printenv` で接続文字列そのものを表示しない。private network の host は `psgl.flycast:5432`、database 名は `flyctl postgres db list -a psgl`、role 名は本手順で作成する `agentsview_*` を使う。password は secret manager / secret shell 側にのみ保持し、URL を echo しない。
> `psgl.flycast` の Fly private network 経由では `sslmode=disable` + `[pg] allow_insecure = true` を使う。外部公開 host で TLS 接続する場合は `sslmode=require` + `allow_insecure = false` に戻す。

### 4. デプロイ

```sh
flyctl deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml
```

または mise task:

```sh
mise run agentsview:deploy
```

`dot_config/agentsview/fly.toml` または `.github/workflows/deploy-agentsview.yaml` を main branch に merge した場合は、GitHub Actions の `deploy-agentsview` workflow が `ryo-agentsview` へ deploy する。必要な GitHub secret は `FLY_API_TOKEN`。

### 5. 動作確認

```sh
# API が 401 を返すこと（認証必須）
curl -i https://ryo-agentsview.fly.dev/api/v1/sessions

# Bearer token で正常応答すること
curl -i -H "Authorization: Bearer <token>" https://ryo-agentsview.fly.dev/api/v1/sessions

# security headers が付いていること
curl -I https://ryo-agentsview.fly.dev
```

`curl -I` では少なくとも `Strict-Transport-Security`、`X-Content-Type-Options`、`X-Frame-Options`、`Referrer-Policy` が返ることを確認する。
`Content-Security-Policy` は AgentsView 本体も返すが、実行時の local/private origin が含まれることがあるため、Fly 側で追加した基本ヘッダーとは分けて見る。

## 複数 PC からのデータ push

各 PC から `mise run agentsview:pg:push` を実行するだけでよい。machine name は未設定なら `hostname` が自動使用され、セッションは PC ごとに区別されて PostgreSQL に蓄積される。

### 各 PC での設定

各 PC のシェル設定（`~/.zshenv` 等、dotfiles には値を含めない）に追記:

```sh
export AGENTSVIEW_PROXY_PG_URL="postgres://agentsview_push_mac:<push-pass>@127.0.0.1:15432/ryo_shellhistory?sslmode=disable"
export AGENTSVIEW_PG_MACHINE="mac-work"
```

`agentsview:pg:status` / `agentsview:pg:push` task は `flyctl proxy 15432:5432 -a psgl` を一時起動し、`AGENTSVIEW_PROXY_PG_URL` を `AGENTSVIEW_PG_URL` として使い、実行後に proxy を停止する。

設定値は、shell に読み込まれているかと、AgentsView が実際に PostgreSQL へ接続できるかを分けて確認する。

```sh
# shell 初期化後に secret shell 側の値が読み込まれているか
# （URL には password が含まれるため、値そのものは表示せず有無だけ確認する）
[ -n "${AGENTSVIEW_PROXY_PG_URL:-}" ] && echo "AGENTSVIEW_PROXY_PG_URL is set" || echo "AGENTSVIEW_PROXY_PG_URL is unset"

# proxy 起動込みで URL の host/db/schema に接続できるか
mise run agentsview:pg:status
```

push も proxy 起動込みで実行する。

```sh
mise run agentsview:pg:push
```

#### secure な local push 構成

目的は、`ryo-agentsview` app は Fly.io 上で起動したまま、ローカル PC から `agentsview pg push` だけを安全に実行すること。

推奨構成は、mise task が `flyctl proxy` を一時起動し、flyctl の user-mode WireGuard 経由で PostgreSQL へ接続する構成。PostgreSQL は public internet に出さない。

```text
local PC
  └─ mise run agentsview:pg:push
       └─ flyctl proxy 15432:5432 -a psgl
            └─ user-mode WireGuard
                 └─ psgl:5432
                      └─ agentsview schema
```

この構成では、ローカル PC から Fly private network までの通信は flyctl の user-mode WireGuard で保護される。AgentsView から見た DB host は `127.0.0.1` なので、local `~/.agentsview/config.toml` に `[pg] allow_insecure = true` を入れなくてよい。

各 PC の secret shell 側:

```sh
export AGENTSVIEW_PROXY_PG_URL='postgres://agentsview_push_mac:<push-pass>@127.0.0.1:15432/ryo_shellhistory?sslmode=disable'
export AGENTSVIEW_PG_MACHINE='mac-work'
```

`psgl.flycast` は Fly private network 用の host のため、WireGuard が有効でない通常のローカル DNS では名前解決できない。`lookup psgl.flycast: no such host` が出る場合は、DB URL や password ではなく private network への経路がないことが原因。
この repository の通常運用では、WireGuard client 常駐や `~/.agentsview/config.toml` の dotfiles 管理は採用しない。`flyctl proxy` を task 内で起動するため、local の AgentsView config に `[pg] allow_insecure = true` を追加する必要はない。

通常の push / status は proxy 起動と停止を task 内で行う。

```sh
export AGENTSVIEW_PROXY_PG_URL='postgres://agentsview_push_mac:<push-pass>@127.0.0.1:15432/ryo_shellhistory?sslmode=disable'
mise run agentsview:pg:status
mise run agentsview:pg:push
```

`127.0.0.1` は local host なので、AgentsView の plaintext guard には通常止められない。

避ける構成:

- `psgl.flycast` を WireGuard なしで使う: local DNS では解決できない。
- PostgreSQL を public internet に出して `sslmode=disable` で使う: 通信経路が安全でない。
- DB password や bearer token を dotfiles に保存する: public repository に漏れるリスクがある。
- Fly app の `AGENTSVIEW_PG_URL` に push 用 role を使う: 公開 viewer 側が書き込み権限を持ってしまう。

public endpoint を使う場合だけ、PostgreSQL 側で TLS を有効にし、URL は `sslmode=require` または `sslmode=verify-full` にする。この場合は `[pg] allow_insecure = true` は不要。

hostname が重複しているか確認したい場合は明示的に設定:

```sh
export AGENTSVIEW_PG_MACHINE="mac-work"   # PC ごとに異なる名前
```

### push 操作

```sh
# 全プロジェクトを push
mise run agentsview:pg:push

# プロジェクトを絞って push（推奨）
mise run agentsview:pg:push -- --projects my-project,other-project

# 全 PC の同期状況確認（machine ごとの件数が表示される）
mise run agentsview:pg:status
```

Web UI（`https://ryo-agentsview.fly.dev`）で全 PC のセッションを一覧できる。

ローカルで `agentsview serve` を起動したい場合:

```sh
mise run agentsview:serve
```

恒久運用は、各 PC の secret shell に `AGENTSVIEW_PROXY_PG_URL` と `AGENTSVIEW_PG_MACHINE` を持たせ、必要なときに `mise run agentsview:pg:push` を実行する形にする。自動常駐 push や `~/.agentsview/config.toml` への DB URL 保存は、この repository では採用しない。

### push 時間について（初回が遅い理由）

初回の全件 push は数時間かかることがある（例: 1353 セッション / 42894 メッセージで約 3h35m）。これは **帯域ではなく往復レイテンシ律速** で、この構成では想定内の挙動。

- push は `flyctl proxy 15432:5432 -a psgl`（user-mode WireGuard）経由で `nrt` リージョンの PostgreSQL に接続するため、全クエリがトンネル越しに東京まで往復する。
- 出力の `Connected to PostgreSQL in 2.89s` や、DDL 数本だけの `PostgreSQL schema ready in 21.122s` が、1 往復あたりのレイテンシが高いことを示すカナリア。行ごとの round-trip 回数 × RTT がそのまま積み上がる。
- **重要: これは一度きりのコスト。** `pg push` は差分同期なので、2 回目以降は新規セッションぶんだけを push し、通常は数秒〜数十秒で終わる。

初回のバルクロードを速くしたい場合の選択肢（任意）:

```sh
# 実 RTT を確認（自宅から遠いと WireGuard の RTT がそのまま効く）
flyctl ping psgl

# リージョン内から実行して RTT を減らす、あるいは初回だけ pg_dump / COPY で
# バルク投入する方法もある。差分運用に入れば体感問題にはならないため、
# 通常は初回の遅さは許容してよい。
```

## データ管理

`pg push` は一方向同期のため、リモート DB のデータは増加し続ける。

### 容量確認

```sh
flyctl postgres connect -a psgl
```

```sql
SELECT pg_size_pretty(pg_schema_size('agentsview'));
```

### 古いデータの削除

```sql
DELETE FROM agentsview.sessions WHERE created_at < NOW() - INTERVAL '6 months';
VACUUM agentsview.sessions;
```

### バックアップ（削除前）

PostgreSQL に全 PC のデータが集約されているため、1回の dump で全端末分がバックアップされる。

```sh
pg_dump -n agentsview \
  "postgres://<user>:<pass>@<host>/<db>" \
  -F c -f ~/backup/agentsview-$(date +%Y%m%d).dump
```

特定 PC のデータのみ削除したい場合:

```sql
DELETE FROM agentsview.sessions WHERE machine = 'mac-old';
```

## GitHub Actions でのデプロイ

`dot_config/agentsview/fly.toml` または workflow 自体を main branch に merge すると `deploy-agentsview` workflow が実行される。

```yaml
- name: Deploy AgentsView
  run: flyctl deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

## token の更新

通常は `AUTH` と `CURSOR` を再生成しない。Bearer token をローテーションしたい場合だけ `AUTH` を更新し、`CURSOR` は既存値を維持する。
既存値を保存していない場合は両方を再生成してよいが、Bearer token は変わる。

```sh
AUTH="<existing-or-new-auth-token>"
CURSOR="<existing-cursor-secret>"

CONFIG_B64=$(
  printf 'public_url = "https://ryo-agentsview.fly.dev"\nrequire_auth = true\nauth_token = "%s"\ncursor_secret = "%s"\n\n[pg]\nallow_insecure = true\n' "$AUTH" "$CURSOR" \
  | base64 | tr -d '\n'
)

flyctl secrets set -a ryo-agentsview \
  AGENTSVIEW_CONFIG_TOML="$CONFIG_B64"

echo "Bearer token: $AUTH"
```

## デプロイ状況メモ

### 根本原因（2026-06-10 特定）

最終的に必要だった修正は以下。

1. Fly.io の `[[files]]` で使う `AGENTSVIEW_CONFIG_TOML` は base64 encode して secret に設定する。
2. `AGENTSVIEW_CONFIG_TOML` には `public_url`、`require_auth`、`auth_token`、`cursor_secret` を含める。
3. Fly app から `psgl.flycast` へ private network 経由で接続する場合は、`sslmode=disable` と `[pg] allow_insecure = true` を使う。
4. 公開 viewer の `AGENTSVIEW_PG_URL` は read-only role、local push の `AGENTSVIEW_PROXY_PG_URL` は push role に分ける。

`cursor_secret` は起動時に config へ自動生成・書き戻しされるが、Fly の `[[files]]` で注入した `/data/config.toml` は secret から再生成されるため、起動時の書き戻しに依存しない。初回 secrets 設定時から `cursor_secret` を明示する。

`AGENTSVIEW_AUTH_TOKEN` 環境変数は AgentsView v0.29.0 の env loader では読まれない。`require_auth` / `auth_token` / `cursor_secret` は `AGENTSVIEW_CONFIG_TOML` から `/data/config.toml` に注入する。

`psgl.flycast` に `sslmode=require` で接続すると、private network 側の PostgreSQL 接続では TLS startup に失敗することがある。Fly app 側は private network 内接続として `sslmode=disable` を使い、AgentsView の plaintext guard は `/data/config.toml` の `[pg] allow_insecure = true` で明示的に許可する。

### 現状（2026-06-10）

- `dot_config/agentsview/fly.toml` は作成済み。
- 公式 image `ghcr.io/wesm/agentsview:0.29.0` を使用し、`PG_SERVE=1` で `agentsview pg serve` を起動する。
- `[[files]]` で `/data/config.toml` を base64 encoded secret から注入する。
- Fly.io app `ryo-agentsview` は作成済み。
- secrets は `AGENTSVIEW_CONFIG_TOML` と `AGENTSVIEW_PG_URL` を使う。
- security headers と HTTPS 強制は `fly.toml` に設定済み。
- setup / deploy / local push は `dot_config/mise/tasks/agentsview.toml` の `agentsview:*` task に集約済み。
- `dot_config/agentsview/fly.toml` の main merge 時 deploy は `.github/workflows/deploy-agentsview.yaml` で自動化済み。

### 次の確認

Bearer token なし API が `401` を返すことを確認する。

```sh
curl -i https://ryo-agentsview.fly.dev/api/v1/sessions
```

保存済み bearer token 付き API が `200` 系を返すことを確認する。`AUTH` と `CURSOR` は通常ローテーション不要で、保存済みの値があれば再利用する。

```sh
curl -i -H "Authorization: Bearer <auth_token>" https://ryo-agentsview.fly.dev/api/v1/sessions
```

各 PC の `AGENTSVIEW_PROXY_PG_URL` が shell に読み込まれていることと、AgentsView が proxy 経由で DB に接続できることを確認する。

```sh
printenv AGENTSVIEW_PROXY_PG_URL
mise run agentsview:pg:status
```

1プロジェクトだけ先に push し、migration とデータ増加を確認する。

```sh
mise run agentsview:pg:push -- --projects <project>
mise run agentsview:pg:status
```

最後に Web UI で push した session が表示されることを確認する。

```sh
open https://ryo-agentsview.fly.dev
```
