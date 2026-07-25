# DOTFILE-11: fnox で平文 `.env` / `.envrc` を置かない運用への移行計画

## 概要

- 目的は、ローカルに平文の `.env` / `.envrc` / `*.secret` を置かずに、`fnox` で秘密情報を注入できる dotfiles 設定へ寄せること。
- このリポジトリでは、`fnox` / Bitwarden / `aws-vault` の役割分担、zsh / mise / AI permission の更新方針、セットアップ手順の文書化までを扱う。
- 他リポジトリごとの `fnox.toml` 作成や secret 登録作業自体は、このリポジトリ外なので本チケットのスコープ外とする。

## 要件

### 機能要件

- `fnox` を用いた secret 注入フローを dotfiles 上で再現できること。
- `npm run` / `make test` / `mise run` 実行時の secret 取り扱い方針が明文化されていること。
- Bitwarden Password Manager、Bitwarden Secrets Manager、`aws-vault` の役割分担が整理されていること。
- AI ツールが平文 secret ファイルを読みにくい deny 設定へ更新する方針が定義されていること。

### 非機能要件

- 平文 secret を新たに git 管理しないこと。
- 既存の `chezmoi` + Bitwarden 連携を壊さないこと。
- 対話的な日常作業の UX を大きく下げないこと。

### 制約条件

- このセッションでは実装に入らず、計画作成と Linear への提出までに留める。
- 作業対象はこのリポジトリ内のみで、他リポジトリやユーザーホーム配下の実 secret は触らない。
- `git fetch origin main` は sandbox 制約で `.git/FETCH_HEAD` に書き込めず失敗するため、pull 同期結果は取得できない可能性がある。

## 調査結果

### 1. `fnox` の前提

- `fnox` は `fnox.toml` で secret を扱い、保存方式として「暗号化した値を git に置く」か「リモート secret への参照だけを置く」の 2 系統を取れる。
- shell integration (`eval "$(fnox activate zsh)"`) により、`fnox.toml` があるディレクトリに `cd` した時点で環境変数を自動展開できる。
- mise integration (`jdx/mise-env-fnox`) もあり、`mise run` と組み合わせた env 注入や cache が可能。
- quick start のまま `fnox set` を使うと plain text default を置けるため、本件では `provider = "age"` か remote provider を必須にして平文保存を避ける必要がある。

### 2. Bitwarden の使い分け

- Bitwarden Password Manager (`bw`) は `BW_SESSION` を使う人間向けの vault access で、既存の `chezmoi` テンプレートや login item 参照と相性がよい。
- Bitwarden Secrets Manager (`bws`) は `BWS_ACCESS_TOKEN` を使う machine / DevOps 向けで、`fnox` の自動 secret 注入に向く。
- そのため、既存の `chezmoi` 用途は Password Manager を維持しつつ、アプリケーション用 env の第一候補は Secrets Manager に寄せるのがよい。
- 小規模な bootstrap 情報だけをローカル保持する必要がある場合は、`age` で暗号化した `fnox` secret を使う。

### 3. `aws-vault` との併用

- `fnox` の `aws-sm` provider は AWS credential chain か `AWS_PROFILE` を使えるため、`aws-vault` と同居できる。
- ただし `fnox` は子プロセスを起動する前に AWS 上の secret を解決するため、標準パターンは `aws-vault exec <profile> -- fnox exec -- <command>` とするのが安全。
- `credential_process = aws-vault export ...` を AWS config に入れて `AWS_PROFILE=<profile> fnox exec -- <command>` とする構成も可能だが、導入難易度が上がるため補足扱いにする。

### 4. 現行 dotfiles の状態

- 既存 secret 連携は `dot_config/chezmoi/chezmoi.toml` の `[bitwarden] unlock = "auto"` と、`dot_config/zsh/dot_zprofile` / `dot_config/zsh/lazy/main.zsh` の `*.secret` source が中心。
- `dot_config/zsh/work.zsh` では `direnv hook zsh` が有効だが、`fnox` は未導入。
- `dot_claude/settings.json` の deny は `.env.*` のみで、`.env` / `.envrc` / `*.secret` / `fnox.local.toml` は未カバー。
- `dot_config/mise/config.toml` には Bitwarden CLI はあるが、`fnox` / `bws` / `aws-vault` は未定義。

## 実装計画

### 1. ツール導入と bootstrap 導線を整える

- `dot_config/mise/config.toml` に `fnox` と `bws` を追加する。
- AWS 系ツールの分離方針を踏まえ、`aws-vault` は `dot_config/mise/config.work2.toml` 追加を第一候補にする。
- 既存の `bitwarden/clients` と `chezmoi` の auto unlock 設定は維持し、既存フローとの後方互換性を保つ。

### 2. 日常コマンド実行時の secret 注入経路を決める

- 基本経路は zsh shell integration にして、`cd` 後は `npm run` / `make test` / `mise run` がそのまま環境変数を継承する形にする。
- `mise` を多用する別リポジトリ向けには、`mise-env-fnox` plugin を setup 文書で併記する。
- AWS Secrets Manager を使うケースは `aws-vault exec <profile> -- fnox exec -- <command>` を標準例として示す。

### 3. AI ガードと secret ファイル運用を更新する

- `dot_claude/settings.json` の deny を `.env`, `.envrc`, `*.secret`, `fnox.local.toml` まで広げる。
- plain text default を残す `.env` / `.envrc` / `fnox.local.toml` 運用は非推奨とし、`fnox.toml` には暗号文または remote reference のみを置くルールを明文化する。
- `direnv` は他リポジトリ互換のため即時撤去せず、`fnox` と併存させた上で `.envrc` に secret を書かない方針に切り替える。

### 4. セットアップと運用手順を文書化する

- `setup.md` に `fnox` / `bws` / `aws-vault` の導入手順を追加する。
- Bitwarden Password Manager と Secrets Manager の違い、採用基準、標準実行例を記載する。
- `fnox.toml` サンプルでは `provider = "age"` または `provider = "bitwarden-sm"` / `provider = "aws-sm"` を使い、plain text default を例示しない。

## 技術的課題と対応策

- `BW_SESSION` は期限切れがあるため、Password Manager を自動 env 注入の主経路にすると UX が不安定になる。
  - 対応策: Password Manager は既存 `chezmoi` / 人間向け secret に限定し、継続利用する env secret は Secrets Manager または AWS Secrets Manager に寄せる。
- `fnox activate zsh` と `direnv hook zsh` の prompt hook 順序で再読込タイミングがずれる可能性がある。
  - 対応策: 実装時に両方有効な shell で `cd` 前後の env 差分を確認する。
- `aws-vault` の mise での導入方法は registry 名の確認が必要。
  - 対応策: 実装時に aqua / ubi のどちらで安定導入できるか検証して採用する。

## 変更対象ファイル

- `dot_config/mise/config.toml`
- `dot_config/mise/config.work2.toml`
- `dot_config/zsh/work.zsh`
- `dot_claude/settings.json`
- `setup.md`
- 必要に応じて新規追加: `dot_config/fnox/**` または secret 運用メモ

## 検証方法

- 静的検証
  - `taplo format --check dot_config/mise/config.toml dot_config/mise/config.work2.toml`
  - `jq . dot_claude/settings.json >/dev/null`
  - `shfmt -d dot_config/zsh/work.zsh`
- 挙動検証
  - `fnox activate zsh` を読み込んだ shell で、`fnox.toml` を置いたサンプルディレクトリに `cd` した時の env 展開を確認する。
  - `fnox exec -- env | rg '^<SECRET_NAME>='` で `npm run` / `make test` 前提の env 注入ができることを確認する。
  - `aws-vault exec <profile> -- fnox exec -- env | rg '^(AWS_|<SECRET_NAME>)'` で AWS credentials と `fnox` secret が同居できることを確認する。
- 安全性検証
  - `rg -n "Read\\(\\*\\*/\\.env|Read\\(\\.env|Read\\(\\*\\*/\\.envrc|Read\\(\\.envrc|fnox\\.local\\.toml|\\*\\.secret" dot_claude/settings.json`

## リスクと未解決事項

- `fnox` の shell integration を global に入れる場所を `work.zsh` に寄せるか共通 zsh に寄せるかは、適用対象ホストの整理が必要。
- Bitwarden Secrets Manager の access token をどこで bootstrap するかは、`age` 暗号化保存と OS keychain 利用の比較が必要。
- `git fetch origin main` はこの環境では sandbox 制約で失敗しており、最新 `origin/main` 取り込み結果は未確認。

## 参考資料

- fnox README / Shell Integration / Mise Integration / Bitwarden / Bitwarden Secrets Manager / AWS Secrets Manager docs
- Bitwarden CLI docs
- Bitwarden Secrets Manager login docs
- aws-vault USAGE.md
