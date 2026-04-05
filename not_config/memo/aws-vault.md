# aws-vault

`aws-vault` は AWS credential を OS の secure storage に保存し、必要なときだけ一時 credential を発行してコマンドやアプリに渡すツールです。macOS では Keychain に寄せられるので、long-lived access key を平文ファイルに置きたくないときに扱いやすいです。

注意点として、upstream の `99designs/aws-vault` は abandoned が明言されています。いまのコマンド体系はまだ広く使われていますが、新規採用時は active fork も合わせて見ておく方が良いと思います。

- upstream
  - https://github.com/99designs/aws-vault
- active fork
  - https://github.com/ByteNess/aws-vault

## 向いている用途

- IAM user の access key を macOS Keychain などに保存したい
- `aws` CLI を一時 credential で実行したい
- AWS Console を profile ごとに開きたい
- GUI ツールや長時間動く SDK ベースのアプリに refresh 可能な credential を渡したい

## インストール

macOS なら Homebrew で十分です。

```sh
brew install aws-vault
```

## backend

`aws-vault` は backend を差し替えられます。代表的なのは以下です。

- macOS Keychain
- Windows Credential Manager
- Secret Service / KWallet
- `pass`
- encrypted file

backend は `--backend` または `AWS_VAULT_BACKEND` で切り替えられます。macOS なら何か事情がない限り Keychain をそのまま使うのが自然です。

```sh
export AWS_VAULT_BACKEND=keychain
```

## まず使う流れ

### credential を登録する

```sh
aws-vault add work
```

### 登録済み profile と session を確認する

```sh
aws-vault list
```

### 一時 credential でコマンドを実行する

```sh
aws-vault exec work -- aws sts get-caller-identity
```

shell ごと入ることもできます。

```sh
aws-vault exec work
```

### AWS Console を開く

```sh
aws-vault login work
```

### credential や session を消す

credential 自体を削除するなら `remove`、一時 session だけ落とすなら `clear` です。

```sh
aws-vault remove work
aws-vault clear work
```

## MFA / role / SSO

### MFA と role assumption

role を使う profile は `~/.aws/config` に普通に書けます。`aws-vault` は `GetSessionToken` や `AssumeRole` を使って一時 credential を払い出します。

```ini
[profile work]
mfa_serial = arn:aws:iam::123456789012:mfa/your-user
region = ap-northeast-1

[profile work-admin]
source_profile = work
role_arn = arn:aws:iam::123456789012:role/AdministratorAccess
region = ap-northeast-1
```

MFA のコード入力を毎回手でやりたくないなら `mfa_process` が便利です。OTP を出せるコマンドを profile にぶら下げます。

```ini
[profile work]
mfa_serial = arn:aws:iam::123456789012:mfa/your-user
mfa_process = op item get aws-work-mfa --otp
```

### SSO

AWS CLI v2 の SSO 設定も使えます。pure SSO 環境なら `aws sso login` だけで足りることも多いですが、`aws-vault exec` に包むと command 単位で profile を明示しやすいです。

```ini
[sso-session company]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access

[profile work-sso]
sso_session = company
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = ap-northeast-1
```

```sh
aws-vault exec work-sso -- aws sts get-caller-identity
```

## `--server` を使う場面

`aws-vault exec --server` は local metadata server を立て、SDK 側が必要に応じて credential を refresh できる形にします。長時間動く GUI ツールや `terraform` のように処理時間が長いものと相性が良いです。

```sh
aws-vault exec --server work -- terraform plan
```

macOS のデスクトップアプリを開く例です。

```sh
aws-vault exec --server work -- open -W -a Lens
```

## `taws` とどう使い分けるか

- `aws-vault`
  - secure storage と session 発行が役割
  - access key を `~/.aws/credentials` に置かずに済む
  - CLI / GUI / SDK を temporary credential で包む
- `taws`
  - リソース観察用の TUI
  - profile / region の切り替えや JSON / YAML 参照が役割

IAM user key を安全に持ちたいなら `aws-vault`、SSO / role を含めた調査画面が欲しいなら `taws`、両方欲しいなら `aws-vault exec <profile> -- taws --readonly` の併用が扱いやすいです。

## caveat

- upstream は abandoned が宣言されている
- 新機能や将来のメンテナンス性が気になるなら active fork も確認する
- それでも現時点では `add` / `exec` / `login` / `list` / `clear` の操作体系が広く知られていて、既存運用に乗せやすい

## この repo での使い方

この repo では、次のように分けると整理しやすいです。

1. long-lived credential の保管は `aws-vault`
2. 変更系コマンドは `aws-vault exec <profile> -- aws ...`
3. 調査や一覧確認は `aws-vault exec <profile> -- taws --readonly`

pure SSO だけで回っていて keychain に置く secret が無いなら、`aws-vault` を無理に挟まず `aws sso login` + `AWS_PROFILE` でも十分です。

## 参考

- `aws-vault` README
  - https://github.com/99designs/aws-vault
- `aws-vault` USAGE
  - https://github.com/99designs/aws-vault/blob/master/USAGE.md
