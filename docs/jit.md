# jitpass (`jit`)

[`jitpass/jit`](https://github.com/jitpass/jit) は、開発端末上の平文 credential を
Touch ID で保護されたローカル vault に移し、許可したプロセスへ必要な時だけ渡すための
macOS 向け CLI。`.env`、shell export、AWS credential、Docker/Git credential helper、
各種 CLI token などを対象にできる。

> 現時点の公式 prebuilt binary は **Apple Silicon macOS 専用**。また、vault を開いた後に
> credential を受け取ったプロセスのメモリまでは保護しない。アカウント侵害への対策や
> credential の rotation の代わりにはならない。

## このリポジトリでの導入設定

公式が推奨する Homebrew formula を `bootstrap:mac-packages` から導入する。

```sh
mise run bootstrap:mac-packages
```

このタスクは Apple Silicon で `brew install jitpass/tap/jitpass` を実行し、導入済みなら
何もしない。Intel Mac では prebuilt binary がないため skip する。Homebrew 経由では
download に quarantine attribute が付き、初回実行前に Gatekeeper が署名と notarization
ticket を検証できる。セキュリティツールなので、mise の GitHub backend や `curl | tar` で
binary を直接置く方法は採用しない。

単独で手動導入する場合も同じ公式 formula を使う。

```sh
brew install jitpass/tap/jitpass
jit doctor
```

`jit doctor` の `jit` 行で署名の Team ID が `CZC6BH93GJ` と表示されることを確認する。
Homebrew なら shell completion も同時に導入される。公式の最新要件は
[Install](https://github.com/jitpass/jit#install) を参照する。

## 初回セットアップ

### 1. 平文 credential を調査する

```sh
# home directory 全体を調査（read-only）
jit scan

# まず対象を狭く調べる場合
jit scan ~/.aws ~/src/my-project

# category ごとの詳細を表示
jit scan --full
```

`jit scan` は対象ファイルを書き換えず、実値を完全な形では表示しない。ただし引数なしでは
home directory 全体を走査するため、初回は時間がかかることがある。

### 2. vault を初期化する

```sh
jit vault init
```

master key は macOS login Keychain に保存され、Touch ID（または macOS の認証）が求められる。
vault の実データは dotfiles に追加しない。

### 3. migration を preview して適用する

最初から home directory 全体を変更せず、まず 1 project で `--dry-run` する。

```sh
jit migrate ~/src/my-project --dry-run
jit migrate ~/src/my-project
```

実行時には変更計画と確認プロンプトが出る。対象ファイルは書き換え前に暗号化 backup される。
`.env` などは通常ファイルから named pipe (FIFO) を使う live mount に変わる場合があるため、
**未コミットの変更を先に確認し、migration 後にも `git status` を確認する**。

問題があれば直前の migration を復元できる。

```sh
jit migrate undo
```

1 project で挙動を確認した後、`jit scan` の提案に従って個別 path、または端末全体へ広げる。

```sh
jit migrate --dry-run
jit migrate
```

### 4. 状態と診断を確認する

```sh
jit status
jit doctor
```

最初の migration 時に background service が自動設定される。`status` は vault、service、mount、
profile の概要確認、`doctor` は署名、backup、shim、secret envelope を含む詳細診断に使う。

## 日常の使い方

### project の command に secret を渡す

```sh
# 通常: profile の値を command の環境変数へ注入
jit run -- npm run dev

# docker compose の env_file など、command が .env 自体を読む場合
jit run --live -- docker compose up

# GCP ADC など machine-global credential を明示する場合
jit run --with gcp -- terraform plan

# project の live mount と global credential の両方が必要な場合
jit run --live --with gcp -- command
```

まず通常の `jit run -- <command>` を使い、command が `.env` file を直接読む場合だけ `--live`
を追加する。詳細は公式の [Run a command with secrets](https://github.com/jitpass/jit/blob/main/docs/run/index.md)
を参照する。

### CLI token を wrap する

`gh`、`glab`、`stripe` など自身の設定ファイルに token を保存する CLI は、一度 wrap すれば
以後は通常どおりの command 名で使える。

```sh
jit wrap gh
gh pr list
```

どの tool が `migrate` / `wrap` / credential helper の対象かは
[Supported tools](https://github.com/jitpass/jit/blob/main/docs/tools.md) で確認する。

### 長時間処理や AI agent に期限付きで許可する

離席中の agent や長時間処理では、対象 process、profile、期限を限定した grant を事前に作る。

```sh
jit grant --process claude --profile my-project --for 8h
jit grant list
jit grant revoke <grant-id>
```

無期限に consent を無効化するより、期限付き grant を優先する。grant は実行した terminal の
process tree に限定されるが、許可対象と期限を確認してから Touch ID を承認する。

### session を管理する

```sh
# 直ちに lock
jit lock

# idle timeout を変更（例: 15分）
jit service ttl 15m

# 利用履歴を確認
jit audit
```

default では vault の unlock と、各 tool へ credential を渡す最初の consent は別の確認になる。
vault が開いていても意図しない process に secret を渡さないため、通常は consent を有効のまま
運用する。

## 更新

Homebrew 管理にそろえ、次で更新する。

```sh
brew update
brew upgrade jitpass
jit doctor
```

`jit upgrade` にも署名と checksum を検証する self-update があるが、このリポジトリでは
導入元を Homebrew に一本化するため `brew upgrade jitpass` を使う。更新しても vault は保持される。

## トラブルシューティング

### `jit run` でも設定が空に見える

command が環境変数ではなく `.env` file 自体を開いている可能性がある。

```sh
jit run --live -- <command>
```

### Touch ID prompt が多い

service の状態と TTL を確認する。

```sh
jit status
jit service ttl
```

一括処理だけを承認する場合は `jit run --trust -- <command>`、離席を伴う場合は期限付き
`jit grant` を検討する。利便性だけを理由に `jit service consent off` を常用しない。

### migration を戻したい

```sh
jit migrate undo
```

復元後に `git status` と対象 tool の動作を確認する。vault を含めて削除する操作は recovery
不能になり得るため、`jit uninstall --purge` を安易に実行しない。

## 関連資料

- [jitpass documentation](https://github.com/jitpass/jit/blob/main/docs/index.md)
- [Quickstart](https://github.com/jitpass/jit/blob/main/docs/getting-started/quickstart.md)
- [Security architecture](https://github.com/jitpass/jit/blob/main/docs/security/architecture.md)
- [Command reference](https://github.com/jitpass/jit/blob/main/docs/reference/commands/jit.md)
