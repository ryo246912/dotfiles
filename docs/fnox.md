# fnox

[fnox](https://github.com/jdx/fnox) は secret を `fnox.toml` で宣言的に管理し、shell / CI から
環境変数として注入するツールです。目的は「ローカルに平文の `.env` / `.envrc` / `*.secret` を置かない」こと
（`plan/DOTFILE-11.md` 参照）。値そのものは git に置かず、暗号化した ciphertext か、リモート secret
ストアへの参照キーだけを `fnox.toml` に置きます。

## age / fnox / dotenvx / sops のどれを使うべきか

4つは役割が違うので、素朴に「1つ選ぶ」ものではありません。

| ツール    | 何をするか                                         | secret の保存場所                         | 主な用途                                                    |
| --------- | -------------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| `age`     | 暗号化アルゴリズム/CLI 単体                        | どこでもいい（自分でファイル管理）        | 単発ファイルの暗号化（fnox の中では provider の1つ）        |
| `dotenvx` | `.env` を暗号化して git 管理できるようにするツール | 暗号化 `.env` を git に置く               | `.env` ファイルという形式を維持したいチーム                 |
| `sops`    | YAML/JSON/ENV/INI の**値だけ**を暗号化するエディタ | 部分暗号化したファイルを git に置く       | k8s manifest や設定ファイルの構造を保ったまま秘匿したい場合 |
| `fnox`    | secret の**注入・参照の統一レイヤー**              | 複数 provider（暗号化 or リモート）を横断 | provider を切り替えても呼び出し側は変えない                 |

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

| provider             | 認証                            | 向いている用途                                                |
| -------------------- | ------------------------------- | ------------------------------------------------------------- |
| `age`                | recipients に登録した鍵         | ローカル専用の小さい bootstrap 値（例: `BWS_ACCESS_TOKEN`）   |
| `bitwarden-sm` (bws) | `BWS_ACCESS_TOKEN`（machine）   | アプリ/サービス用 env の第一候補。セッション切れがない        |
| `bitwarden` (bw)     | `BW_SESSION`（human, 期限あり） | 既存の Bitwarden Password Manager item をそのまま参照したい時 |
| `aws-sm`             | AWS credential chain            | AWS 上で完結する secret、`aws-vault` との併用                 |

Bitwarden は 2 系統あります（Password Manager と Secrets Manager の違い・project の概念・両者を
連携できるか等は `docs/bitwarden.md` を参照）。`chezmoi` は `[bitwarden] unlock = "auto"` で Password Manager (`bw`) を
使っており、既にこのセッションが有効になっています。**`fnox` の `bitwarden` provider は同じセッションを
再利用するだけ**なので、chezmoi のテンプレート関数 `bitwarden "item" "..."` で値を静的ファイルに
展開する代わりに、`fnox exec` / `fnox activate` で実行時に注入する形に置き換えられます
（`dot_config/fnox/config.toml` の `[providers.bitwarden]` 参照）。

実例: `czg`（cz-git）の AI コミット生成トークンは、以前は `dot_config/dot_czrc.tmpl` が
`bitwarden "item" "GitHub PAT(cz-git)"` で値を `~/.config/.czrc` に平文展開していました。
`czg` は `openAIToken` の代わりに **`CZ_OPENAI_API_KEY` 環境変数**を読めるため、この secret は
env var 注入で完全に代替できます。今は `.czrc`（`dot_config/dot_czrc`）から `openAIToken` を削除して
`apiEndpoint`/`apiModel` のみの非 secret な静的ファイルにし、トークンは `dot_config/fnox/config.toml`
の `CZ_OPENAI_API_KEY` secret から注入しています。

この secret は当初 `bitwarden` (bw) provider を使っていましたが、`BW_SESSION` のセッション切れを
避けるため `bitwarden-sm` (bws) provider に切り替えました。bws の machine account token には
セッション切れが無いため、`env = "exec"` にする必要がなくなり、`fnox activate` によるシェルへの
自動注入（デフォルトの `env = true`）をそのまま使えます。

判断基準:

- ツールが env var を読める → `fnox`（デフォルトでこちらを検討する。plain な `KEY=VALUE` ならほぼ必ず
  env 対応があるので、chezmoi テンプレートで平文展開する前に一度ツールのドキュメントを確認する）
- ツールが env を一切読まず、ファイルの中身として値が必要（バイナリ形式の証明書など） →
  chezmoi の `bitwarden` テンプレートを使う

## shell 統合

`dot_config/zsh/lazy/mise.zsh`（`HOST_ENV` に関係なく全ホストで読み込まれる）で `fnox activate zsh` を
有効化しています。`work.zsh` 限定にしていないのは、fnox が work 用途に限らない汎用の secret 注入だから
です。`fnox.toml` があるディレクトリに `cd` すると、その shell で `npm run` / `make test` / `mise run`
がそのまま secret を継承します。

非対話実行や shell hook を使わない場面では `fnox exec -- <command>` を使います。

```sh
fnox exec -- npm run dev
fnox exec -- make test
fnox exec -- mise run lint-json
```

### 常時 shell に注入せず、使うときだけ解決したい secret

`fnox activate` は shell hook（`cd` での再評価、および fnox 自身のドキュメントによれば prompt 表示時の
変更検知も含む）のたびに、設定されている secret を解決しにいきます。正確な再評価タイミングは fnox の
バージョンやシェルにより変わり得ますが、実務上は「`cd` するたびに毎回」で十分起きうる頻度です。
`bw`（Bitwarden Password Manager）のようにセッション (`BW_SESSION`) が定期的に切れる provider を
デフォルトのまま使うと、セッション切れのたびに shell 側でログインを求められて煩わしくなります。

これを避けるには、secret ごとに `env` フィールドを指定します:

| `env` の値     | 挙動                                                                      |
| -------------- | ------------------------------------------------------------------------- |
| `true`（既定） | `fnox activate` によるシェルへの自動注入 + `fnox exec` の両方で解決される |
| `"exec"`       | `fnox exec -- <command>` 実行時にだけ解決される。シェルには自動注入しない |
| `false`        | 自動注入されない。`fnox get <NAME>` で明示的に取得した時だけ解決される    |

> [!IMPORTANT]
> 文字列の `env = "exec"`（exec-only モード）は **fnox v1.30.0 以降**で追加された機能です。
> それ未満のバージョンでは config 読込時に
> `invalid type: string "exec", expected a boolean` が出て**設定ファイル全体の読込に失敗**します
> （`env` が boolean しか受け付けないため）。このリポジトリは `dot_config/mise/config.toml` で
> `github:jdx/fnox` を v1.30.0 以上（現在 1.31.1）に pin しているので、`mise install` で更新すれば
> 解消します。古い fnox が残っている場合は `fnox --version` を確認してください。

`bws` / `aws-sm` のように機械向けで期限切れしにくい provider は `env = true`（既定）のままで
問題ありません（`dot_config/fnox/config.toml` の `CZ_OPENAI_API_KEY` も bws provider なのでこの
既定のままです）。`bw` のようにセッションが切れる provider を使う secret を追加する場合にだけ、
「使うときだけ必要な secret」として `env = "exec"` にして `fnox exec` 経由に倒すのが基本方針です。

## グローバル設定と work profile の分割

`dot_config/fnox/config.toml`（グローバル）と `dot_config/fnox/config.work.toml`（work profile）の
2ファイルに分けています。mise が `config.toml` + `config.work2.toml` のように役割ごとにファイルを
分けているのと揃える狙いです。ただし fnox には `MISE_ENV` に相当する「ホスト種別で自動的にファイルを
選ぶ」機能が無いため、次の2つを組み合わせて実現しています。

- `config.toml` の先頭で `import = ["config.work.toml"]` を宣言し、同じディレクトリ
  （`$FNOX_CONFIG_DIR`）にある `config.work.toml` を明示的に取り込む（fnox の `import` は
  「現在の config ファイルからの相対パスで他の TOML を merge する」機能）。
- `config.work.toml` 側は中身をすべて `[profiles.work.*]` の下に置く。これは
  `FNOX_PROFILE=work` のときだけ有効になるので、import されているだけでは何も起きない。
- `dot_config/zsh/dot_zshenv.tmpl` が `HOST_ENV` に work ロール（`work1` / `work2`）が含まれる
  ホストだけ `FNOX_PROFILE=work` を export する（`MISE_ENV` を `HOST_ENV` から導出しているのと
  同じ仕組み）。

会社アカウント固有の provider（仕事用 `bws` project、`aws-sm` + `aws-vault` 併用など）は
`config.work.toml` に置き、個人用途のもの（`age` bootstrap、個人の `bws` project、
`czg` トークンなど）は `config.toml` に残します。

両ファイルとも未使用の provider/secret はコメントアウトしたひな形として置いていますが、
TOML は同じテーブル（`[secrets]` や `[profiles.work.secrets]`）をファイル内で複数回宣言できません。
有効化するときは、新しい `[secrets]` / `[profiles.work.secrets]` を追加で書かず、既存の1つの
テーブルに `KEY = { ... }` の行を足す形にしてください（各ファイルのコメントにもその旨を明記しています）。

## aws-vault との併用

`fnox` の `aws-sm` provider は AWS credential chain（環境変数 / `AWS_PROFILE` / IAM role）で認証するため、
`aws-vault` と同居できます。標準パターンは `aws-vault exec <profile> -- fnox exec --profile work -- <command>`
です（`--profile work` は上記の work profile を有効化するため）。`aws-vault` が
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` を子プロセスの環境変数として渡すため、
`config.work.toml` 側の `[profiles.work.providers.aws]` に `profile` を書かなければそのまま拾われます。

複数 AWS アカウント/ロールを切り替える場合は `[profiles.<aws_profile>]` で `aws-vault` のプロファイル名と
揃えた独立した profile を追加で定義してください。テンプレートは `dot_config/fnox/config.work.toml`
末尾のコメントアウト済みブロック（`aws-vault の複数アカウント/ロールをさらに細かく切り替えたい場合`）を
参照してください。

```sh
aws-vault list
aws-vault exec <aws_profile> -- fnox exec --profile <aws_profile> -- <command>
```

zsh 側の abbreviation は `dot_config/zabrze/general.toml` の `aws-vault` 系 (`awv` / `awe` / `awl` /
`awlo`) と `dot_config/zabrze/fnox.toml` の `fnox` 系 (`fna` = activate, `fne` = exec, `fnv` = aws-vault
exec + fnox exec) を参照してください。

## セットアップ手順

`fnox` / `bws` は `dot_config/mise/config.toml` に pin 済みなので、`mise install` すれば入ります。
以下は各 provider を実際に有効化する手順です。

### 1. Bitwarden Password Manager (`bitwarden` provider)

追加のセットアップは不要です。`chezmoi` が `[bitwarden] unlock = "auto"` で `bw` を自動アンロックして
おり、`fnox` の `bitwarden` provider（`dot_config/fnox/config.toml` の `[providers.bitwarden]`）は
そのセッションをそのまま使い回します。動作確認:

```sh
bw status # "unlocked" になっていること
```

現状このリポジトリで `bitwarden` (bw) provider を参照する secret は無く（`CZ_OPENAI_API_KEY` は
下記の bws provider に移行済み）、`BW_SESSION` のセッション切れの影響を受けたくない secret を
追加するときは基本的に bws を優先してください。既存の Password Manager item をそのまま参照したい
場合にだけこの provider を使い、`fnox get <secret名>` で動作確認します。

### 2. Bitwarden Secrets Manager (`bitwarden-sm` provider, `bws`)

`BWS_ACCESS_TOKEN` は machine account の access token で、`bw` のようなセッション切れが無い代わりに
「このトークン自体をどう安全に保管するか」という bootstrap 問題があります。fnox 公式の解決策は
`age` でトークン自体を暗号化して git 管理下に置くことです。

1. age keypair を作る（まだ無ければ）。`age-keygen` は `dot_config/mise/config.toml` の
   `aqua:FiloSottile/age` として pin してあるので `mise install` すれば使えます:
   ```sh
   age-keygen -o ~/.config/fnox/age-identity.txt
   chmod 600 ~/.config/fnox/age-identity.txt
   ```
   出力される `age1...` から始まる公開鍵を `dot_config/fnox/config.toml` の
   `[providers.age].recipients` に追加してコメントを外す。`recipients` は暗号化に使う公開鍵の
   **リスト**です（後述の複数 PC 対応のため、複数指定できる）。復号には別途秘密鍵の場所を fnox に
   伝える必要があるため、同じ `[providers.age]` に `key_file` も設定する（`FNOX_AGE_KEY_FILE`
   環境変数で渡す方法もあるが、恒常的に使うならここに書く方が漏れない）:
   ```toml
   [providers.age]
   type = "age"
   recipients = ["age1..."]
   key_file = "~/.config/fnox/age-identity.txt"
   ```
2. Bitwarden の Web Vault → **Secrets Manager** → **Machine accounts** で新規 machine account を
   作成し、そこから access token を発行する（有効期限は要件に応じて設定。無期限も可）。
3. 発行したトークンを age で暗号化してグローバル設定に保存する（この1回だけ hidden prompt に平文を
   入力する。トークンをコマンド引数にそのまま渡すと shell history や `ps` に残るため避ける）:
   ```sh
   fnox set --global --provider age BWS_ACCESS_TOKEN
   ```
   `--global` を付けると、この ciphertext は `~/.config/fnox/config.toml`
   （＝このリポジトリの `dot_config/fnox/config.toml` がデプロイされたファイル）に直接書き込まれます。
   暗号化済みなので、その差分をそのまま git commit して問題ありません（コミットし忘れると、次の
   `chezmoi apply` でこのファイルがソース側の内容に戻され、せっかく設定した ciphertext が消える
   ので注意）。
4. `dot_config/zsh/lazy/mise.zsh` の `fnox` セクションが `eval "$(fnox activate zsh)"` の直前に
   `fnox get BWS_ACCESS_TOKEN` の結果を export する処理を入れてあるため、一度上記の `fnox set` を
   済ませれば、以降はシェルを開くたびに自動で環境変数へ展開されます。まだ `fnox set` していない
   環境（初期セットアップ前）でも `fnox get` が黙って失敗するだけで、shell の起動自体は落ちません。
5. `dot_config/fnox/config.toml`（個人用）の `[providers.bws]` は `CZ_OPENAI_API_KEY` 用に既に
   有効化済みです。`project_id` を自分の Secrets Manager project ID に置き換えてください。
   会社用の project を追加する場合は `dot_config/fnox/config.work.toml`（会社用）の
   `[profiles.work.providers.bws]` ブロックのコメントを外し、同様に `project_id` を設定します。
6. 動作確認:
   ```sh
   fnox get CZ_OPENAI_API_KEY   # config.toml の場合
   fnox exec --profile work -- env | rg '^SOME_APP_API_KEY='   # config.work.toml の場合
   ```

#### 複数 PC で使う場合（2台目以降のセットアップ）

age の秘密鍵は PC ごとに別々に生成するのが基本です（同じ秘密鍵ファイルを複数マシンにコピーして
使い回すことも技術的には可能ですが、鍵の運用が煩雑になるため非推奨）。`recipients` は複数の公開鍵を
リストで持てるので、「新しい PC の公開鍵を追加してから、既存の ciphertext をその公開鍵向けに
再暗号化する」という手順になります。

1. 2台目の PC で新しい age keypair を作る（1台目とは別の鍵）:
   ```sh
   age-keygen -o ~/.config/fnox/age-identity.txt
   chmod 600 ~/.config/fnox/age-identity.txt
   ```
2. 出力された公開鍵を、`dot_config/fnox/config.toml` の `[providers.age].recipients` に追記する
   （1台目の公開鍵は消さず、リストに2つ目を足すだけ）。この編集自体は git を扱える側（1台目や
   別の作業環境）で行って構いません。
3. 1台目（今まで使っていた秘密鍵で既存 ciphertext を復号できる側）で、追加した recipient に
   向けて既存の ciphertext を再暗号化する:
   ```sh
   fnox reencrypt --provider age
   ```
   これで `dot_config/fnox/config.toml` 内の `BWS_ACCESS_TOKEN` の ciphertext が、1台目・2台目
   どちらの秘密鍵でも復号できる形に更新されます。
4. `recipients` の追加と再暗号化後の `dot_config/fnox/config.toml` を commit して push する。
5. 2台目で `chezmoi apply`（または `git pull` 後に `chezmoi apply`）すれば、2台目の
   `age-identity.txt` でも `fnox get BWS_ACCESS_TOKEN` が復号できるようになります。

> [!IMPORTANT]
> 2台目の公開鍵を `recipients` に追加しただけで `fnox reencrypt` を忘れると、既存の ciphertext は
> 古い recipients のまま変わらないため、2台目では復号できません。age の暗号文は暗号化した時点の
> recipients がヘッダに埋め込まれる方式で、`recipients` の設定を後から書き換えても既存の ciphertext
> には遡って反映されないためです。

### 3. AWS Secrets Manager + `aws-vault` (`aws-sm` provider)

1. `aws-vault` に AWS credential を登録する（IAM user の access key、または SSO 設定に応じた方法で）:
   ```sh
   aws-vault add <aws_profile>
   aws-vault list
   ```
2. `dot_config/fnox/config.work.toml` の `[profiles.work.providers.aws]` ブロックのコメントを外し、
   `region` / `prefix` を実際の値に置き換える。`profile` は書かない（`aws-vault` が渡す環境変数を
   そのまま拾わせるため。詳しくは [「aws-vault との併用」](#aws-vault-との併用) を参照）。
3. `[profiles.work.secrets]`（既に開いている単一テーブル）に secret 行を追加する。
4. 動作確認:
   ```sh
   aws-vault exec <aws_profile> -- aws sts get-caller-identity   # AWS 認証自体の確認
   aws-vault exec <aws_profile> -- fnox exec --profile work -- env | rg '^(AWS_|DATABASE_URL)'
   ```
5. `HOST_ENV` に work ロール（`work1`/`work2`）が含まれるホストでは、上記の `--profile work` を
   明示しなくても shell 起動時に `FNOX_PROFILE=work` が自動で export されるので、
   `fnox activate zsh` 経由の secret（`env = true` のもの）はそのまま使えます（`env = "exec"` に
   した secret は引き続き `fnox exec` 経由が必要）。

複数 AWS アカウント/ロールを個別に切り替えたい場合は、[「aws-vault との併用」](#aws-vault-との併用)
に書いた `[profiles.<aws_profile>]` の複数プロファイル構成を使ってください。

## secret ファイル運用

- `.env`, `.envrc`, `*.secret`, `fnox.local.toml` には secret を保存しない（`dot_claude/settings.json`
  の deny でこれらの Read/Write は AI ツールからもブロックしている）。
- `fnox.toml` は `provider = "age"` の暗号文か、リモート provider への参照キーのみを持つ
  （plain text default は使わない）。
- このリポジトリ自身（dotfiles）が使う secret は `dot_config/fnox/config.toml`
  （`~/.config/fnox/config.toml` にデプロイされる fnox のグローバル設定）で管理する。
  cwd に関係なく全 shell にマージされるため、複数リポジトリを横断して使う secret
  （例: `czg` の AI トークン）はここに置く。
- 個別プロジェクト用の `fnox.toml` はそのプロジェクトのリポジトリ側に置く。最小構成は以下の形:

  ```toml
  [providers.bws]
  type       = "bitwarden-sm"
  project_id = "xxx"

  [secrets]
  DATABASE_URL = { provider = "bws", value = "DATABASE_URL" }
  ```
