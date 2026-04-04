# taws

`taws` は AWS リソースをターミナルから眺めたり、必要に応じて操作したりするための TUI です。ブラウザを開かずに profile と region を切り替えながら眺めたいときに便利で、特に調査系の作業と相性が良いかなと思います。

この repo では、変更系の操作は `aws` CLI、一覧確認や JSON / YAML の覗き込みは `taws`、長時間の credential 管理は `aws-vault` と分けておくと扱いやすいです。

## 向いている用途

- profile / region を切り替えながら AWS リソースを横断して眺める
- EC2 / Lambda / IAM / CloudWatch Logs などを TUI で素早く確認する
- リソース詳細を JSON / YAML でその場で見る
- `--readonly` を使って、誤操作を避けながら調査専用で使う

## インストール

macOS / Linux なら Homebrew が一番簡単です。

```sh
brew install huseyinbabal/tap/taws
```

あるいは upstream の Releases から配布バイナリを取ってきます。

- https://github.com/huseyinbabal/taws/releases/latest

version の pin はここでは書いていません。`taws` はリリースの動きがあるので、導入時点の latest を見る方が安全です。

## 前提

`taws` 自体は credential を保存するツールではなく、`~/.aws/config` / `~/.aws/credentials` と環境変数を読んで AWS に接続します。先に以下のどれかが済んでいる前提です。

- `aws configure` で access key を設定している
- `aws configure sso` と `aws sso login --profile <profile>` が済んでいる
- `role_arn` を使う profile が `~/.aws/config` に定義されている
- `aws-vault exec <profile> -- taws` の形で一時 credential を渡す

この repo では `dot_config/zsh/lazy/work.zsh.tmpl` ですでに `AWS_CLI_AUTO_PROMPT=on-partial` を有効にしているので、普段の操作は CLI、調査は `taws` という分担にすると迷いにくいです。

## まず使う形

現在の profile / region で起動するならそのままで構いません。

```sh
taws
```

profile や region を切り替えて起動したいときは環境変数で十分です。

```sh
AWS_PROFILE=work-dev AWS_REGION=ap-northeast-1 taws
```

事故を避けたいときは read only で起動します。

```sh
taws --readonly
```

LocalStack や独自 endpoint に向けたいときは `AWS_ENDPOINT_URL` が使えます。

```sh
AWS_ENDPOINT_URL=http://localhost:4566 taws
```

## 認証パターン

### AWS SSO

`taws` は AWS SSO を扱えます。token が切れている場合はブラウザ認証を促し、`aws sso login` 済みなら cached token をそのまま使います。

modern な `sso_session` 形式でも、従来の `sso_start_url` / `sso_region` 形式でも構いません。

```ini
[sso-session company]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access

[profile work-admin]
sso_session = company
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = ap-northeast-1
```

SSO profile を日常的に使うなら、先に `aws sso login --profile work-admin` を済ませてから `AWS_PROFILE=work-admin taws --readonly` の流れが一番素直です。

### AWS Console Login

`aws login` を使う `login_session` 形式もサポートされています。credential が切れていれば別ターミナルで `aws login` を実行するよう促され、既に login 済みなら cached credential を再利用します。

```ini
[profile console-profile]
login_session = my-login-session
region = ap-northeast-1

[login-session my-login-session]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access
```

### IAM Role Assumption

`role_arn` と `source_profile`、または `credential_source` を使う role assumption にも対応しています。cross-account access を見たいときはこの形が基本です。

`source_profile` を使う例です。

```ini
[profile base]
region = ap-northeast-1

[profile production]
role_arn = arn:aws:iam::123456789012:role/ProductionAccess
source_profile = base
region = ap-northeast-1
```

`credential_source` を使う例です。

```ini
[profile env-admin]
role_arn = arn:aws:iam::123456789012:role/AdminRole
credential_source = Environment
region = ap-northeast-1
```

## 便利な設定

### read only を基本にする

`taws` は write 系アクションも持っているので、普段は `--readonly` を基本にしておくと安心です。zsh に雑に alias を置いておくと使いやすいです。

```sh
alias tawsr='taws --readonly'
```

### shell completion を入れる

zsh なら以下で completion を有効化できます。

```sh
eval "$(taws completion zsh)"
```

この repo の local 設定に足すなら `dot_config/zsh/lazy/` 配下へ寄せるのが自然かなと思います。

### 会社ネットワークの証明書を通す

proxy や SSL inspection の都合で AWS API が失敗する場合は、`AWS_CA_BUNDLE` か `SSL_CERT_FILE` を設定します。

```sh
export AWS_CA_BUNDLE=/path/to/corporate-ca-bundle.pem
taws --readonly
```

## `aws-vault` とどう使い分けるか

- `taws`
  - AWS リソースを眺める TUI
  - SSO profile や role profile をそのまま読む
  - 調査や棚卸しを速くするのが主目的
- `aws-vault`
  - 長期 credential を OS の secure storage に置く
  - 一時 credential を払い出して CLI / GUI / SDK に渡す
  - `exec --server` で長く動くツールにも向いている

IAM user の access key を安全に持ちたい、または GUI / SDK ツールに一時 credential を渡したいなら `aws-vault` を併用します。`taws` も `aws-vault` 配下でそのまま起動できます。

```sh
aws-vault exec work-admin -- taws --readonly
```

## この repo での使い方

この repo で素直だと思う流れは以下です。

1. `aws configure sso` または `aws-vault add` で base の認証方法を作る
2. `aws sso login --profile <profile>` もしくは `aws-vault exec <profile> -- zsh` で session を張る
3. 調査は `taws --readonly`
4. 実際の変更や one-shot の操作は `aws` CLI

`dot_config/navi/cheats/aws.cheat.md` に CLI コマンドを寄せておくと、`taws` は調査専用の画面として割り切りやすいです。

## 参考

- `taws` README
  - https://github.com/huseyinbabal/taws
- AWS CLI SSO
  - https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
