# mise bootstrap

`mise bootstrap` は mise の宣言的マシンセットアップ機能。`[bootstrap.*]` に書いた設定と
実際のマシンの状態を比較し、差分だけを収束させる。chezmoi の `run_once_*` スクリプト
（内容ハッシュが変わるとリスト全体の対話プロンプトが再生される、リストから項目を消しても
何も起きない）と違い、**何度実行しても安全**で、**設定ファイルの差分だけが適用される**。

参考: [Bootstrap | mise-en-place](https://mise.jdx.dev/bootstrap.html)、
[brew | mise-en-place](https://mise.jdx.dev/bootstrap/packages/brew.html)、
[macOS defaults | mise-en-place](https://mise.jdx.dev/bootstrap/macos-defaults.html)

## `mise bootstrap` のフェーズ

`mise bootstrap`（フル実行）は以下を順に処理する。

1. `[bootstrap.plugins]` — plugin インストール
2. `[bootstrap.packages]` — システムパッケージ（brew/brew-cask/apt 等）
3. `[bootstrap.repos]` — リポジトリの clone/更新
4. `[dotfiles]` — dotfile 配置（本リポジトリは chezmoi が担当）
5. `[bootstrap.mise_shell_activate]` — シェル activation
6. `[bootstrap.macos.defaults]`（および friendly section の `[bootstrap.macos.finder]` 等）— macOS defaults
7. `[bootstrap.macos.launchd.agents]` — macOS LaunchAgent
8. `[bootstrap.linux.systemd.units]` — Linux systemd user unit
9. `[bootstrap.user]` — ログインシェル（`chsh`）
10. `[tools]` — mise 管理ツール（`mise install` 相当）
11. plugin パッケージマネージャの適用
12. カスタム bootstrap task
13. `[bootstrap.hooks.final]` — 最終フック

上記に加えて、`packages`/`repos`/`dotfiles`/`defaults`/`user`/`tools` の各フェーズには
`[bootstrap.hooks.pre-*]`/`[bootstrap.hooks.post-*]`（例: `pre-packages`、`post-defaults`）
という前後フックもあるが、本リポジトリではどれも使っていない。

このリポジトリでは `mise bootstrap`（フル）は呼んでいない。`.chezmoi.toml.tmpl` の
post-apply hook が個別に `mise bootstrap packages apply` / `mise install` を呼び、
macOS defaults は手動で `mise bootstrap macos defaults apply` を実行する運用にしている
（`sudo` を要する操作を非対話フックに含めたくないため。詳細は後述）。

## このリポジトリでの構成

| 設定                                | ファイル                                   | 内容                                           |
| ----------------------------------- | ------------------------------------------ | ---------------------------------------------- |
| `[bootstrap.packages]`（mac）       | `dot_config/mise/config.mac.toml`          | `brew:`（formula）/ `brew-cask:`（GUI アプリ） |
| `[bootstrap.packages]`（linux/WSL） | `dot_config/mise/config.linux.toml`        | `apt:`                                         |
| `[bootstrap.macos.*]`               | `dot_config/mise/config.mac.toml`          | Finder / キーボード / raw defaults             |
| mise では表現できない個別処理       | `dot_config/mise/tasks/bootstrap-mac.toml` | `mise run bootstrap:mac` 等（後述）            |

`[bootstrap.packages]` はキーが `<manager>:<name>` 形式で、`MISE_ENV`（mac/linux）と
ファイル名（`config.mac.toml`/`config.linux.toml`）で OS ごとに自動的に分離される。値は
基本 `"latest"` で固定バージョン運用はしていない（renovate による個別バージョン追従は
mise 管理外のパッケージ ＝ `dot_config/brew/brew.json` / `brew_cask.json` に限定）。

```toml
# dot_config/mise/config.mac.toml
[bootstrap.packages]
"brew:git"            = "latest"       # CLI（formula）
"brew-cask:firefox"   = "latest"       # GUI アプリ（cask）
```

```toml
# dot_config/mise/config.linux.toml
[bootstrap.packages]
"apt:tig" = "latest"
```

### `MISE_ENV` について

以下のコマンド例には `MISE_ENV` を付けていない。`dot_config/zsh/host-env.map` にホストを
登録していれば（`ryo-mac-xxx=mac,xxx` のように）、`dot_zshenv.tmpl` が対話シェル起動時に
`HOST_ENV`/`MISE_ENV` を自動 export するため、日常的なコマンド実行では明示不要。手元の
`MISE_ENV` を明示的に上書きしたいとき（他 OS 向け設定を意図的に確認する、host-env.map 未登録の
ホスト、`.chezmoi.toml.tmpl` の post-apply hook のように zsh を経由しない非対話コンテキストなど）
だけ `MISE_ENV=mac mise bootstrap ...` のように付ける。

### Homebrew 関連ツールの導入手順

- `[bootstrap.packages]` の `brew:`/`brew-cask:`（`config.mac.toml` の大半）は **実 Homebrew が
  一切不要**。mise 自体（`run_once_install-mise_mac.sh`）さえ入っていれば `mise bootstrap
packages apply` だけで導入できる。実 Homebrew の有無・導入順序に依存しない。
- 実 Homebrew が要るのは、custom install option・postflight・API メタデータ未確認のサードパーティ
  tap を使う例外パッケージ（clibor / google-japanese-ime / thock / jira-cli。理由は後述の表）だけ。
  この実 Homebrew 自体も curl スクリプトを直接叩くのではなく mise task として導入している
  （`[bootstrap.packages]` には載せられない — Homebrew は formula/cask ではなくパッケージマネージャ
  そのものなので、mise の宣言的パッケージ管理の対象にできない）:
  ```sh
  mise run bootstrap:mac-brew      # 実 Homebrew 本体（このタスクでのみ導入）
  mise run bootstrap:mac-packages  # 上記4つの例外パッケージ（bootstrap:mac-brew に依存）
  mise run bootstrap:mac           # まとめて実行
  ```
  実 Homebrew の導入を後回しにしても mise 管理下の `[bootstrap.packages]` には一切影響しない。

### コマンド

`status`/`apply`/`upgrade`/`prune` は既に読み込まれている `[bootstrap.packages]` に対して
動くが、`use`/`import` は設定ファイルへの**書き込み**コマンドで、
`--path`（または `-g`）を指定しない限り**カレントディレクトリのローカル `mise.toml`**に書く
（chezmoi のデプロイ先 `~/.config/mise/config.mac.toml` にも、まして chezmoi の source
（`dot_config/mise/config.mac.toml`）にも自動では書かれない）。このリポジトリは
「常に chezmoi の source を編集する」ルールなので、`use`/`import` を使うときは chezmoi の
source ディレクトリで `--path dot_config/mise/config.mac.toml` を明示するか、素直に
`dot_config/mise/config.mac.toml` を直接編集する方が確実。

```sh
# 状態確認（read-only。何も変更しない）
mise bootstrap packages status
mise bootstrap packages status --missing   # 未同期なら exit 1（CI/hook 向け）

# 実際に導入する
mise bootstrap packages apply
mise bootstrap packages apply --dry-run     # 何が実行されるかだけ確認
mise bootstrap packages apply --yes         # 確認プロンプトなし

# config に新しいパッケージを1個追加してすぐ導入（chezmoi source を明示）
cd "$(chezmoi source-path)"
mise bootstrap packages use brew-cask:slack --path dot_config/mise/config.mac.toml
chezmoi diff && chezmoi apply

# 更新
mise bootstrap packages upgrade

# 設定にない・削除された formula を掃除（cask は未対応。後述）
mise bootstrap packages prune --dry-run
```

zabrze abbr（`dot_config/zabrze/mise.toml`）: `mba` = apply、`mbu` = use、`mbs` = status
（いずれも `uname` から `MISE_ENV` を自組み立てするため、host-env.map 未登録のホストでも動く）。

macOS defaults:

```sh
mise bootstrap macos defaults status
mise bootstrap macos defaults apply
mise bootstrap macos defaults apply --dry-run
```

### `[bootstrap.macos.*]` の書き方

`[bootstrap.macos.dock]` / `[bootstrap.macos.finder]` / `[bootstrap.macos.keyboard]` /
`[bootstrap.macos.trackpad]` は主要な設定を分かりやすいキー名で書ける friendly section。
それ以外は `[bootstrap.macos.defaults]` にドメイン単位の raw key-value を書く
（値の TOML 型がそのまま `defaults write` の型 `-bool`/`-int`/`-float`/`-string` に対応）。

```toml
[bootstrap.macos.finder]
show_all_files = true
show_pathbar    = true

[bootstrap.macos.keyboard]
key_repeat         = 2
initial_key_repeat = 15

[bootstrap.macos.defaults]
"com.apple.finder" = { AppleShowAllExtensions = true, QuitMenuItem = true }
"NSGlobalDomain"    = { "com.apple.swipescrolldirection" = false }
```

**制約**（このリポジトリで実際に踏んだもの）:

- `defaults -currentHost` 相当（ホスト固有の設定。メニューバーのアイコン間隔など）は非対応。
- 値は bool/int/float/string のみ。array/dict（キーボードショートカットの割り当てなど）は非対応。
- macOS の「ログイン項目」に相当する設定はない。`[bootstrap.macos.launchd.agents]` は
  実行ファイル起動用の LaunchAgent 定義で、`.app` バンドルを「ログイン項目」として登録する
  ものではない（システム設定の「ログイン項目」一覧にも出てこない）。

これらは `mise run bootstrap:mac-defaults` / `bootstrap:mac-hotkeys`
（`dot_config/mise/tasks/bootstrap-mac.toml`）に残している。

### mise でも表現できないもの（`dot_config/mise/tasks/bootstrap-mac.toml`）

| タスク                   | 内容                                                                                                                                   | mise で表現できない理由                                                                       |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `bootstrap:mac-brew`     | Homebrew 本体の導入                                                                                                                    | bootstrap 前提そのもの（mise 自体は別途 run_once で導入。後述）                               |
| `bootstrap:mac-packages` | clibor（`--language=ja`）/ google-japanese-ime（Rosetta 前提）/ thock（独自 tap + `thock --install` postflight）/ jira-cli（独自 tap） | custom install option・前提コマンド・postflight・（API メタデータ未確認の）サードパーティ tap |
| `bootstrap:mac-defaults` | メニューバー間隔・ログイン項目                                                                                                         | 上記の `-currentHost` / login item 制約                                                       |
| `bootstrap:mac-hotkeys`  | キーボードショートカット                                                                                                               | plist が array/dict                                                                           |

いずれも `if ! <条件> ; then <導入> ; fi` 形式の冪等処理で、何度実行しても安全。
y/n の対話確認はあえて撤廃した（`mise run` を明示的に叩くこと自体が確認に相当する、という
mise bootstrap の思想に合わせた）。

## mise 自体のインストールについて

mise 自身は **mise task にできない**（`mise run` を使うには mise が既にインストール済みで
なければならず、循環してしまう）。そのため mise 本体は mise 非依存な方法で導入する:

- mac: `run_once_install-mise_mac.sh`（chezmoi の run_once スクリプト。mise が無ければ
  `curl https://mise.run | sh` を実行するだけ）
- Windows/WSL: `run_once_install-packages_windows.sh` 内で同じ方式（`curl https://mise.run | sh`）

どちらも `~/.local/bin/mise` に入る（`MISE_INSTALL_PATH` 未指定時のデフォルト）。
`.chezmoi.toml.tmpl` の post-apply hook はこの `~/.local/bin` を PATH の先頭に通してから
`mise bootstrap packages apply` 等を呼ぶ。

以前は mac だけ `brew install mise` で導入していたが、Homebrew と違い mise は
`[bootstrap.packages]` の `brew:` では"自分自身"を導入できない（同じ循環問題）ため、
Windows/WSL 側と方式を揃えて `https://mise.run` のインストールスクリプトに統一した。

## 既に brew で導入済みの状態からのマイグレーション手順

このリポジトリは元々 `run_once_install-packages_mac.sh` から `brew install` /
`brew install --cask` で直接インストールしていた。`[bootstrap.packages]` に移した後、
**同じマシンに既にインストール済みのものをどう扱うか** の手順。

### 前提: なぜ多くの場合そのまま動くか

mise の `brew:`/`brew-cask:` バックエンドは、Apple Silicon では実 Homebrew と**同じ正規
prefix**（`/opt/homebrew`）を直接読み書きする。mise が pour した formula も実 brew の
`INSTALL_RECEIPT.json` 互換の receipt を書くため、`brew list`/`brew upgrade` からも
mise 管理の formula に見える。逆に、**実 brew で先に入れていたものも mise 側から見える**
（同じ Cellar/prefix を見ているだけなので、再インストールなしにそのまま「導入済み」と
認識される）。

つまり **formula は基本的にアンインストール不要**。cask は import/prune が未実装なため
少し手順が異なる（後述）。

### 手順1: formula（brew:）

既にインストール済みの formula を丸ごと `[bootstrap.packages]` にインポートできる。
`import` も書き込みコマンドなので、`use` と同様に `--path` で chezmoi の source を明示する
（省略するとカレントディレクトリのローカル `mise.toml` に書かれてしまう）。

```sh
cd "$(chezmoi source-path)"
# 現在の(オンリクエストな)formulaをスキャンして [bootstrap.packages] に書き出す
mise bootstrap packages import --manager brew --path dot_config/mise/config.mac.toml
# 依存関係で入った formula も含めたい場合
mise bootstrap packages import --manager brew --all --path dot_config/mise/config.mac.toml
```

`import` は `brew bundle dump` 相当。サードパーティ tap の formula は fully-qualified な
名前（`brew:owner/tap/formula`）で書き出され、GitHub の慣例的な tap URL が推測できる場合は
`[bootstrap.brew.taps]` も自動で追記される。

`import` は source ファイルを書き換えるだけなので、`chezmoi diff`/`chezmoi apply` で
デプロイしてから確認する:

```sh
chezmoi diff && chezmoi apply
mise bootstrap packages status   # 差分がないことを確認（= 追加インストール不要）
```

差分なしのはず。もし差分が出る場合は、tap が Homebrew API メタデータ
（`api/formula/<name>.json`）を公開していない可能性がある（下記「サードパーティ tap の注意」
参照）。

### 手順2: cask（brew-cask:）

**`mise bootstrap packages import` は cask に対応していない**
（"Cask import/prune is not implemented" — cask のアンインストール手順が app/pkg
アーティファクトに対して安全に実装できるまでの間、formula のみ対応）。手動で
`[bootstrap.packages]` に追記する。

```sh
# インストール済み cask の一覧とバージョンを確認（書き出しの元ネタ）
brew list --cask --versions
```

1. 上記の出力を見ながら `dot_config/mise/config.mac.toml`（chezmoi source）に
   `"brew-cask:<token>" = "latest"` を追記し、`chezmoi apply` でデプロイする。
2. **read-only** で確認する（何も変更しない）:
   ```sh
   mise bootstrap packages status
   ```
   すでに導入済みの cask が `installed`/`satisfied` として認識されれば **アンインストール不要**
   （mise が同じ `<prefix>/Caskroom` を直接見て認識している）。
3. `--dry-run` で実際の挙動を確認する:
   ```sh
   mise bootstrap packages apply --dry-run
   ```
4. 結果による判断:
   - **satisfied** → 何もしなくてよい。
   - **missing 扱いだが単に再インストールしようとしている** → app-bundle 系の cask
     （`.app` を `/Applications` に展開するだけのもの）は、公式の同じアーティファクトを
     上書き展開するだけなので、基本的にアンインストール不要でそのまま `apply` してよい。
     macOS の権限許可（Accessibility 等）は bundle ID / コード署名に紐づくため、
     再インストールしても通常は保持される。アプリの設定・データは
     `~/Library/Application Support` 等にあり、`/Applications` の再展開では消えない。
   - **conflict エラー**（mise が「自分が作ったものではない」として拒否する） →
     該当の cask だけ個別に対応する:
     ```sh
     brew uninstall --cask <name>   # --zap は付けない（設定ファイルまで消えることがある）
     mise bootstrap packages apply
     ```
     全部まとめてアンインストールする必要はない。conflict が出たものだけでよい。

まとめて32個試すよりも、まずリスクの低いアプリ1〜2個で `apply` して挙動を確認してから
残りに広げるのが安全。

### サードパーティ tap の注意

`brew:`/`brew-cask:` でサードパーティ tap（例: `owner/tap/formula`）を使うには、その tap が
Homebrew API メタデータ（`api/formula/<name>.json` / `api/cask/<token>.json`）を実際に
公開している必要がある（`brew tap-new` が生成する GitHub Actions で自動生成されるのが典型）。
古い/小規模な tap では未対応なことがあり、その場合 `mise bootstrap packages apply` は
インストールできずに失敗する。

このリポジトリでは `thock`（`kamillobinski/thock`）と `jira-cli`
（`ankitpokhrel/jira-cli`）について API メタデータの公開有無を確認できなかったため、
`[bootstrap.packages]` には移行せず `mise run bootstrap:mac-packages`
（実 `brew tap`/`brew install`）のまま残している。**`.chezmoi.toml.tmpl` の post-apply
hook は `mise bootstrap packages apply` の失敗を fatal 扱いする**ため、未確認の tap を
安易に `[bootstrap.packages]` に入れると、hook 全体を壊すリスクがある。追加する場合は
先に `mise bootstrap packages apply --dry-run` で個別に検証してから。

### mise 自体を brew から乗り換える場合

`brew install mise` で導入していた mise を `https://mise.run` 方式に統一する場合:

```sh
brew uninstall mise
curl https://mise.run | sh
```

設定・shims（`~/.local/share/mise`）はどちらのインストール方法でも共通なので、
入れ替えても `[tools]`/`[bootstrap.packages]` の状態は失われない。
