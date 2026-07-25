# fnox

[fnox](https://github.com/jdx/fnox) は secret を `fnox.toml` で宣言的に管理し、shell / CI から
環境変数として注入するツールです。目的は「ローカルに平文の `.env` / `.envrc` / `*.secret` を置かない」こと
（`plan/DOTFILE-11.md` 参照）。値そのものは git に置かず、暗号化した ciphertext か、リモート secret
ストアへの参照キーだけを `fnox.toml` に置きます。

## age / fnox / dotenvx / sops のどれを使うべきか

4つは役割が違うので、素朴に「1つ選ぶ」ものではありません。

| ツール      | 何をするか                                          | secret の保存場所                             | 主な用途                                   |
| ----------- | ----------------------------------------------------- | ---------------------------------------------- | ------------------------------------------- |
| `age`       | 暗号化アルゴリズム/CLI 単体                          | どこでもいい（自分でファイル管理）             | 単発ファイルの暗号化（fnox の中では provider の1つ） |
| `dotenvx`   | `.env` を暗号化して git 管理できるようにするツール    | 暗号化 `.env` を git に置く                    | `.env` ファイルという形式を維持したいチーム |
| `sops`      | YAML/JSON/ENV/INI の**値だけ**を暗号化するエディタ    | 部分暗号化したファイルを git に置く            | k8s manifest や設定ファイルの構造を保ったまま秘匿したい場合 |
| `fnox`      | secret の**注入・参照の統一レイヤー**                 | 複数 provider（暗号化 or リモート）を横断      | provider を切り替えても呼び出し側は変えない |

- `age` は暗号化の実装そのもの（`age -e -r <recipient>` でファイルを暗号化するだけ）。fnox はこれを
  「providers.age」として内部で使っており、単体の `age` コマンドを直接運用する場面はほぼありません。
- `dotenvx` は `.env` というファイル形式を保ったまま暗号化する発想です。既存の dotenv ワークフロー
  （`.env` を読むツールが多い）との親和性は高い一方、secret の出どころは「暗号化 `.env` を git に
  コミットする」の1系統に固定されます。リモート secret ストア（Bitwarden / AWS SM など）と併用したい
  場合は別立てで統合が要ります。
- [`sops`](https://github.com/getsops/sops) は YAML/JSON/ENV/INI/BINARY を対象に、**キーはそのまま・
  値だけ暗号化**するのが特徴です。ファイル全体を暗号化する `age` と違い、`git diff` でどのキーが
  変わったかが読めます。鍵バックエンドは age/PGP/AWS KMS/GCP KMS/Azure Key Vault などを選べ、
  `sops exec-env` / `sops exec-file` で復号した値をプロセスに注入することもできます。ただし secret の
  出どころは「暗号化ファイルを git に置く」の1系統で、fnox のようにリモート secret ストア（Bitwarden
  や AWS SM の「参照キーだけ git に置く」方式）は持ちません。Kubernetes manifest や Terraform tfvars
  のように**構造を保ったまま**秘匿したいファイルに向いていて、単純な `KEY=VALUE` の env secret には
  `age`/dotenvx や fnox の方がシンプルです。
- `fnox` の強みは **provider を差し替えても `fnox.toml` の構造と `fnox exec` / `fnox activate` という
  呼び出し方が変わらない**ことです。ローカル開発では `age` 暗号化、ステージングでは Bitwarden Secrets
  Manager、本番では AWS Secrets Manager、といった使い分けを1つの設定ファイル形式（`[profiles.<name>]`）
  で表現できます。ローテーションも「fnox は常に最新版を取得する」ため、ciphertext を選んだとき以外は
  git 側の更新が不要です。`sops` と役割が重なるのは「git に暗号化して置く」ケースだけで、fnox は
  それに加えてリモート参照も同じ形式で扱える点が異なります。

このリポジトリでは **fnox を第一選択にしています**。理由は、secret の置き場所（age 暗号化 / bws /
aws-sm / bitwarden）を後から変えても `fnox.toml` の骨格と shell 側の呼び出し方（後述）が変わらないため、
プロジェクトごとの secret 事情（チームで共有したい／個人ローカルだけでよい／AWS 前提）に合わせて
provider だけ差し替えられるからです。`dotenvx` は「`.env` という形式に強くこだわりがある」場合の、
`sops` は「YAML/JSON の構造を保ったまま秘匿したい」場合の選択肢として残りますが、このリポジトリが
扱うのは基本的に `KEY=VALUE` の env secret なので、複数 provider を横断できる fnox の方が構造的に合います。

## provider の使い分け

| provider           | 認証                          | 向いている用途                                             |
| ------------------- | ----------------------------- | ------------------------------------------------------------ |
| `age`               | recipients に登録した鍵      | ローカル専用の小さい bootstrap 値（例: `BWS_ACCESS_TOKEN`） |
| `bitwarden-sm` (bws) | `BWS_ACCESS_TOKEN`（machine） | アプリ/サービス用 env の第一候補。セッション切れがない       |
| `bitwarden` (bw)    | `BW_SESSION`（human, 期限あり） | 既存の Bitwarden Password Manager item をそのまま参照したい時 |
| `aws-sm`             | AWS credential chain           | AWS 上で完結する secret、`aws-vault` との併用                |

Bitwarden は 2 系統あります。`chezmoi` は `[bitwarden] unlock = "auto"` で Password Manager (`bw`) を
使っており、既にこのセッションが有効になっています。**`fnox` の `bitwarden` provider は同じセッションを
再利用するだけ**なので、chezmoi のテンプレート関数 `bitwarden "item" "..."` で値を静的ファイルに
展開する代わりに、`fnox exec` / `fnox activate` で実行時に注入する形に置き換えられます
（`dot_config/fnox/fnox.toml.sample` の `[providers.bitwarden]` 参照）。

ただし chezmoi のテンプレート展開が必要な場面は残ります。例えば `dot_config/dot_czrc.tmpl` のように
**サードパーティツールが読む静的な設定ファイルに値を直接書き込む必要がある**場合は、env var 注入では
代替できないため、そこは今まで通り `bitwarden` テンプレート関数を使い続けます。判断基準:

- 実行時に環境変数として渡せる（アプリ側が env を読む） → `fnox`
- ツールが env を読まず、ファイルの中身として値が必要 → 引き続き chezmoi の `bitwarden` テンプレート

## shell 統合

`dot_config/zsh/work.zsh` で `fnox activate zsh` を有効化しています。`fnox.toml` があるディレクトリに
`cd` すると、その shell で `npm run` / `make test` / `mise run` がそのまま secret を継承します。

非対話実行や shell hook を使わない場面では `fnox exec -- <command>` を使います。

```sh
fnox exec -- npm run dev
fnox exec -- make test
fnox exec -- mise run lint-json
```

## aws-vault との併用

`fnox` の `aws-sm` provider は AWS credential chain（環境変数 / `AWS_PROFILE` / IAM role）で認証するため、
`aws-vault` と同居できます。標準パターンは `aws-vault exec <profile> -- fnox exec -- <command>` です。
`aws-vault` が `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` を子プロセスの環境変数
として渡すため、`fnox.toml` 側の `[providers.aws]` に `profile` を書かなければそのまま拾われます。

複数 AWS アカウント/ロールを切り替える場合は `[profiles.<aws_profile>]` で `aws-vault` のプロファイル名と
揃えたプロファイルを `fnox.toml` に定義してください。テンプレートは
`dot_config/fnox/fnox.toml.sample` の末尾（`aws-vault multi-account template`）を参照してください。

```sh
aws-vault list
aws-vault exec <aws_profile> -- fnox exec --profile <aws_profile> -- <command>
```

zsh 側の abbreviation は `dot_config/zabrze/general.toml` の `aws-vault` 系 (`awv` / `awe` / `awl` /
`awlo`) と `fnox` 系 (`fna` = activate, `fne` = exec, `fnv` = aws-vault exec + fnox exec) を参照してください。

## secret ファイル運用

- `.env`, `.envrc`, `*.secret`, `fnox.local.toml` には secret を保存しない（`dot_claude/settings.json`
  の deny でこれらの Read/Write は AI ツールからもブロックしている）。
- `fnox.toml` は `provider = "age"` の暗号文か、リモート provider への参照キーのみを持つ
  （plain text default は使わない）。
- プロジェクトごとの `fnox.toml` は `dot_config/fnox/fnox.toml.sample` を雛形にする。
