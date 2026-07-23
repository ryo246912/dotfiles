# DOTFILE-121 agentsview pg-sync セルフホスト計画

## 目的とスコープ

AgentsView の PostgreSQL Sync を使い、複数端末のセッション情報を共有 PostgreSQL に集約し、Fly.io 上の read-only Web UI から参照できるようにする。dotfiles 側では、ローカルからの `pg push` を実行しやすくする設定と、Fly.io にデプロイするための設定ファイルを追加する。

この計画フェーズでは実装を行わず、実装対象・検証方法・リスクを明確化する。実装は Linear 上で計画承認を受けてから開始する。

## 調査結果

- リポジトリ内では AgentsView が `dot_config/mise/config.toml` に `github:wesm/agentsview = "0.27.0"` として導入済み。
- `dot_config/zabrze/ai.toml` には通常の `agentsview serve` スニペットのみあり、`agentsview pg push/status/serve` の導線は未整備。
- Atuin は `dot_config/atuin/fly.toml` で Fly.io に `ryo-shellhistory` としてデプロイする構成があり、`auto_stop_machines = "stop"`、`min_machines_running = 0`、`shared-cpu`/256MB の低コスト構成を既に使っている。
- AgentsView 公式ドキュメントでは PostgreSQL Sync はローカル SQLite から PostgreSQL への一方向同期で、`agentsview pg push` が on-demand でセッションを push し、`agentsview pg serve` が PostgreSQL を read-only UI として配信する方式。
- AgentsView Docker イメージ `ghcr.io/wesm/agentsview` は `PG_SERVE=1` で `agentsview pg serve` 起動に切り替えられる。ただし API をリモート公開する場合は `require_auth = true` を設定する必要がある。
- AgentsView の bearer token 認証は `/api/` 配下に適用される。静的 HTML/JS/CSS は未認証でも取得できるため、公開 URL 自体を秘密として扱わず、API 認証・TLS・origin 制限・secret 管理を必須防御線にする必要がある。
- `pg serve` では bearer token を `Authorization` ヘッダーで渡すのが基本で、SSE の `?token=` はログ・履歴・Referer に残り得る。公開運用では token 付き URL を共有しない運用を明記する。
- AgentsView の `auth_token` は `config.toml` に保存できる。Fly 上では自動生成 token が起動ログに出るリスクを避けるため、`AGENTSVIEW_AUTH_TOKEN` を Fly secret として渡し、entrypoint が `/data/config.toml` に書き込む方式を計画に含める。
- AgentsView 公式 GitHub の最新リリースは v0.29.0。現在の dotfiles は v0.27.0 のため、pg-sync まわりの挙動差を減らす目的で更新を検討する。
- Fly.io の現行ドキュメントでは、すべての利用者に恒久的な無料枠がある前提ではなく、Legacy Free allowances または Free Trial 条件に依存する。完全無料運用は現在の Fly.io 組織の課金条件確認が必要。

参考:

- https://www.agentsview.io/pg-sync/
- https://www.agentsview.io/remote-access/
- https://github.com/wesm/agentsview
- https://fly.io/docs/reference/configuration/
- https://fly.io/docs/about/pricing/

## 要件

### 機能要件

- ローカル端末から `agentsview pg push` で PostgreSQL にセッションを同期できる。
- Fly.io 上で `agentsview pg serve` を起動し、PostgreSQL の内容を read-only Web UI として公開できる。
- 公開 UI は bearer token 認証を必須にする。
- 公開 URL は常に HTTPS に強制し、AgentsView には `public_url` と最小限の `public_origins` を設定する。
- 公開 dotfiles には `AGENTSVIEW_PG_URL`、`AGENTSVIEW_AUTH_TOKEN`、DB role のパスワード、実 token を含めない。
- PostgreSQL 接続 URL や認証トークンなどの秘密情報は dotfiles にコミットしない。
- 既存 Atuin PostgreSQL インスタンスを共用できる場合は、AgentsView 用 schema を分けて利用する。
- Atuin DB を共用する場合でも、可能なら AgentsView 専用 role を作り、`agentsview` schema に必要な DDL/DML 権限だけを与える。
- 既存 DB 共用ができない場合は、Fly.io の無料または最小コスト条件を満たす PostgreSQL 構成を別途使う。

### 非機能要件

- Fly.io app は既存 Atuin と同様に `auto_stop_machines = "stop"`、`auto_start_machines = true`、`min_machines_running = 0` を使い、常時稼働コストを抑える。
- 最小構成は `shared-cpu-1x`/256MB から開始し、起動失敗や OOM があれば 512MB への変更を検討する。
- PostgreSQL 接続は remote DB 前提で `sslmode=require` 以上を使う。
- PostgreSQL 接続は可能なら `sslmode=verify-full` を優先し、少なくとも `sslmode=require` と `allow_insecure = false` を維持する。
- AgentsView の `auth_token` は永続 volume 内の `/data/config.toml` に保存され、再起動ごとに不要にローテーションしない。
- Fly app のレスポンスには可能な範囲で `Strict-Transport-Security`、`X-Content-Type-Options`、`Referrer-Policy`、`X-Frame-Options` を付与し、公開 URL の基本的なブラウザ側防御を追加する。
- `result_content_blocked_categories` の既定値を弱めず、session transcript に secret や個人情報が含まれ得ることを前提に push 対象 project の絞り込みを検討できる導線を用意する。
- `~/.agentsview/config.toml` 全体を chezmoi 管理しない。AgentsView が自動生成する `auth_token` などの動的設定を dotfiles apply で破壊しないため。

### 制約条件

- 実装前に計画承認が必要。
- Fly.io の実デプロイや secret 設定には Fly 認証と PostgreSQL 接続情報が必要。認証や secret が利用できない場合は、設定ファイル作成とローカル静的検証までを完了し、ブロッカーとして記録する。
- 現在の作業環境では `git fetch origin main` が `.git/FETCH_HEAD` への書き込み権限で失敗した。`git ls-remote origin refs/heads/main` では remote main が `34d08fb`、現在 HEAD が `ef56119` のため、実装開始前に同期ブロッカーとして扱う。

## 実装方針

### 1. AgentsView バージョンとローカル導線

- `dot_config/mise/config.toml` の `github:wesm/agentsview` を v0.29.0 に更新する。
- `dot_config/zabrze/ai.toml` に以下のスニペットを追加する。
  - `agentsview pg push`
  - `agentsview pg status`
  - `agentsview pg serve`
- `dot_config/navi/cheats/fly.cheat.md` または AgentsView 用 cheat に、Fly デプロイ・secret 設定・ログ確認・PostgreSQL 接続確認のコマンド例を追加する。
- `AGENTSVIEW_PG_URL` は secret shell 側で管理する前提とし、公開 dotfiles には値を含めない。
- `AGENTSVIEW_PG_MACHINE` や project filter の指定例を追加し、公開 DB に送る session 範囲を制御できるようにする。

### 2. Fly.io AgentsView app 設定

- `dot_config/agentsview/fly.toml` を新規追加する。
- app 名は `ryo-agentsview` を候補にする。
- `primary_region = "nrt"`、`[http_service] internal_port = 8080`、`force_https = true`、`auto_stop_machines = "stop"`、`auto_start_machines = true`、`min_machines_running = 0` を設定する。
- `[[vm]]` は `cpu_kind = "shared"`、`cpus = 1`、`memory_mb = 256` を初期値にする。
- `AGENTSVIEW_PG_SCHEMA = "agentsview"`、`AGENTSVIEW_DISABLE_UPDATE_CHECK = "1"` など非秘密情報だけ `[env]` に置く。
- `AGENTSVIEW_PG_URL` と `AGENTSVIEW_AUTH_TOKEN` は `fly secrets set` で設定する。
- `[http_service.http_options.response.headers]` に HSTS、nosniff、referrer policy、frame deny を追加する。CSP は UI 破壊リスクがあるため、実ブラウザ検証後に必要なら別途追加する。

### 3. Fly 用起動ラッパー

- `dot_config/agentsview/Dockerfile` を新規追加し、`ghcr.io/wesm/agentsview` をベースにする。
- `dot_config/agentsview/fly-entrypoint.sh` を新規追加する。
- entrypoint は `/data/config.toml` が存在しない場合のみ初期設定を書き込む。
  - `require_auth = true`
  - `auth_token = "${AGENTSVIEW_AUTH_TOKEN}"`
  - `public_url = "https://<app>.fly.dev"`
  - `public_origins = ["https://<app>.fly.dev"]`
  - `[pg] url = "${AGENTSVIEW_PG_URL}"`
  - `[pg] schema = "agentsview"`
- 起動時に `AGENTSVIEW_PG_URL` と `AGENTSVIEW_AUTH_TOKEN` が未設定なら fail fast する。
- `/data/config.toml` は `0600` で作成し、entrypoint では `set -x` を使わず secret をログに出さない。
- 既存 `/data/config.toml` がある場合は `auth_token` を保持し、`require_auth = true`、`public_url`、`public_origins`、`[pg]` が欠けている場合のみ補完する。
- 最後に `agentsview pg serve --host 0.0.0.0 --no-browser` を実行する。

### 4. PostgreSQL 構成

- 第一候補: 既存 Atuin 用 Fly PostgreSQL を共用し、AgentsView は schema `agentsview` を使う。
- 共用時は Atuin のテーブルや schema と衝突しないこと、接続 role に schema 作成・migration 権限があることを確認する。
- 共用時は Atuin の application role や superuser をそのまま使わず、可能なら AgentsView 専用 role と専用 schema に分離する。初回 migration に必要な DDL 権限と、通常運用に必要な DML 権限を確認する。
- 共用できない場合は、別 PostgreSQL app/cluster を使う。ただし Fly.io の現行料金では完全無料を保証できないため、課金条件を workpad に記録して判断する。
- AgentsView 側 schema は `pg serve` 起動時または `pg push` 初回実行時に自動 migration される前提で検証する。

### 5. 公開 URL のセキュリティ方針

- URL が公開される前提で、URL の秘匿性には依存しない。
- 静的 UI が未認証で取得できることは仕様として許容し、session 一覧・message・tool call などの実データを返す API が token なしで `401` になることを acceptance gate にする。
- token は Fly secret から注入し、起動ログ・Linear コメント・dotfiles・cheat の例に実値を出さない。
- `Authorization: Bearer` を前提にし、`?token=` 付き URL はログ・履歴・Referer 漏えいリスクがあるため使用しない運用にする。
- transcript には prompt、ファイルパス、コマンド出力、secret 断片が含まれる可能性があるため、初回 push 前に project filter / exclude filter を検討する。
- Fly app の公開面は HTTPS 強制、最小 origin、基本 security headers、DB TLS、DB schema/role 分離で守る。IP allowlist や private networking が必要になった場合は別チケット化する。

## 変更予定ファイル

- `dot_config/mise/config.toml`
  - AgentsView の mise 管理バージョンを v0.29.0 に更新する。
- `dot_config/zabrze/ai.toml`
  - pg-sync 関連スニペットを追加する。
- `dot_config/navi/cheats/fly.cheat.md`
  - AgentsView 用 Fly deploy/secrets/logs/status コマンド例を追加する。
- `dot_config/agentsview/fly.toml`（新規）
  - Fly.io app 設定、HTTPS 強制、基本 security headers、非秘密 env を追加する。
- `dot_config/agentsview/Dockerfile`（新規）
  - AgentsView Docker image をベースに Fly 用 entrypoint を組み込む。
- `dot_config/agentsview/fly-entrypoint.sh`（新規）
  - `/data/config.toml` の初期化と `pg serve` 起動を行う。

## 検証方法

### 静的検証

- `git diff --check`
- `taplo fmt --check dot_config/agentsview/fly.toml dot_config/mise/config.toml dot_config/zabrze/ai.toml`
- `shellcheck dot_config/agentsview/fly-entrypoint.sh`
- `fly config validate -c dot_config/agentsview/fly.toml`（`flyctl` が利用可能な場合）

### ローカル動作検証

- `agentsview --version` で v0.29.0 が参照されることを確認する。
- `AGENTSVIEW_PG_URL` が利用可能な場合、`agentsview pg status` で PostgreSQL 接続と schema 設定を確認する。
- `AGENTSVIEW_PG_URL` が利用可能な場合、`agentsview pg push --projects <検証対象>` または通常の `agentsview pg push` を実行し、`agentsview pg status` で session/message 数が増えることを確認する。

### Fly 動作検証

- Fly 認証と secret が利用可能な場合、`fly deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml` を実行する。
- `fly status -a ryo-agentsview` で Machine が正常起動することを確認する。
- `fly logs -a ryo-agentsview` で `pg serve` が PostgreSQL に接続し、migration または schema compatibility check が成功していることを確認する。ログに `AGENTSVIEW_AUTH_TOKEN`、`auth_token`、PostgreSQL パスワードが出ていないことも確認する。
- `https://ryo-agentsview.fly.dev` の静的 UI が取得できることを確認する。
- `/api/` 配下が bearer token なしで `401` になることを確認し、`require_auth = true` が有効であることを確認する。
- `Authorization: Bearer <token>` 付き API リクエストで正常応答することを確認する。
- `curl -I https://ryo-agentsview.fly.dev` で HSTS、nosniff、referrer policy、frame deny が返ることを確認する。
- `http://ryo-agentsview.fly.dev` が HTTPS にリダイレクトされることを確認する。
- `public_origins` が `https://ryo-agentsview.fly.dev` に限定され、想定外 origin からの API 呼び出しが許可されないことを確認する。

## リスクと対応

- Fly.io の無料条件が現在の組織に適用されない可能性がある。
  - 対応: 既存 Atuin DB 共用と auto-stop 構成を第一候補にし、料金条件を確認できない場合は「完全無料未確定」としてブロッカーに記録する。
- 既存 Atuin DB の接続情報や Fly 認証がこの作業環境で利用できない可能性がある。
  - 対応: dotfiles の設定追加と静的検証まで進め、実デプロイ・DB 接続検証は blocker として workpad に記録する。
- 256MB VM では AgentsView の起動や migration が不安定な可能性がある。
  - 対応: まず 256MB で検証し、OOM や health check timeout が出た場合のみ 512MB へ変更する。
- `pg push` は自動バックグラウンド同期ではなく on-demand である。
  - 対応: スニペット/cheat に push 操作を明示し、必要なら後続チケットで cron/launchd 化を検討する。
- PostgreSQL Sync は一方向同期で、永久削除は PostgreSQL 側へ反映されない。
  - 対応: 仕様として workpad と完了コメントに記録し、削除運用は直接 SQL か後続課題に分離する。
- 公開 URL から static asset は見えるため、認証済み API の守りが壊れると transcript が露出する。
  - 対応: `require_auth = true`、token secret 注入、API 401 検証、ログ秘匿確認、HTTPS/security headers を acceptance gate にする。
- bearer token を query parameter で使うと、ログ・履歴・Referer に残る可能性がある。
  - 対応: cheat と plan では `Authorization` ヘッダー利用を基本にし、`?token=` 付き URL の共有を禁止事項として記載する。
- Atuin DB 共用時に権限が広すぎる role を使うと、AgentsView 側の設定漏れや漏えい時に Atuin データにも影響する。
  - 対応: 専用 schema と専用 role を優先し、共用 DB でも権限境界を分ける。

## 未解決事項

- この作業環境で Fly.io 認証と対象 PostgreSQL 接続 URL が利用可能か。
- 既存 Atuin DB の role が AgentsView schema の作成・migration 権限を持つか。
- 既存 Atuin DB 上に AgentsView 専用 role を作れるか。作れない場合、どの権限の接続 URL を Fly secret に入れるか。
- Fly.io 組織が Legacy Free allowances の対象か、または現行料金で許容可能な最小コストになるか。
- `ghcr.io/wesm/agentsview` の version tag を v0.29.0 で固定できるか。固定できない場合は公式 README と同様に `latest` を使う。
- 公開 URL を bearer token のみで許容するか、IP allowlist / Flycast / VPN 前提にするか。後者は追加実装が必要なため、別チケット候補にする。
