# mise bootstrap

`mise bootstrap` は mise の宣言的マシンセットアップ機能。`[bootstrap.*]` に書いた設定と
実際のマシンの状態を比較し、差分だけを収束させる。**何度実行しても安全**で、**設定ファイルの差分だけが適用される**。

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
という前後フックもある。

### Homebrew 関連ツールの導入手順

- `[bootstrap.packages]` の `brew:`/`brew-cask:`（`config.mac.toml` の大半）は **実 Homebrew が
  一切不要**。mise 自体さえ入っていれば `mise bootstrap
packages apply` だけで導入できる。実 Homebrew の有無・導入順序に依存しない。
- 実 Homebrew が要るのは、Rosetta 前提・postflight・sudo が要る pkg インストーラ・
  API メタデータ未確認のサードパーティ tap・mise 未対応の cask artifact 種別を使う例外パッケージ:
  ```sh
  mise run bootstrap:mac-brew      # 実 Homebrew 本体（このタスクでのみ導入）
  mise run bootstrap:mac-packages  # 例外パッケージ（bootstrap:mac-brew に依存）
  mise run bootstrap:mac           # まとめて実行
  ```

### コマンド

#### CLI から formula/cask を直接導入する

ワンショットで導入するだけなら `apply`、設定にも残して導入するなら `use` を使う。

```sh
# 導入するだけ（mise.toml には書き込まない）
mise bootstrap packages apply brew:jq
mise bootstrap packages apply brew-cask:slack

# [bootstrap.packages] に追加して導入する
mise bootstrap packages use brew:jq
mise bootstrap packages use brew-cask:slack
```

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

zabrze abbr（`dot_config/zabrze/mise.toml`）: `mba` = apply、`mbu` = use、`mbs` = status。

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

## 既に brew で導入済みの状態からのマイグレーション手順

元々は `brew install` /
`brew install --cask` で直接インストールしていた。`[bootstrap.packages]` に移した後、
**同じマシンに既にインストール済みのものをどう扱うか** の手順。

### 前提: なぜ多くの場合そのまま動くか

mise の `brew:`/`brew-cask:` バックエンドは、Apple Silicon では実 Homebrew と**同じ正規
prefix**（`/opt/homebrew`）を直接読み書きする。mise が pour した formula も実 brew の
`INSTALL_RECEIPT.json` 互換の receipt を書くため、`brew list`/`brew upgrade` からも
mise 管理の formula に見える。逆に、**実 brew で先に入れていたものも mise 側から見える**
（同じ Cellar/prefix を見ているだけなので、再インストールなしにそのまま「導入済み」と
認識される）。

つまり **formula は基本的にアンインストール不要**。ただし `openssl@3`/`ca-certificates` の
ような共有依存を real brew が既に掴んでいる場合は `cannot link` で失敗することがある
（「brew で個別導入済みのパッケージと衝突する場合」参照）。cask は import/prune が未実装な
ため少し手順が異なる（後述）。

### brew で個別導入済みのパッケージと衝突する場合

すでに `brew install` で直接導入済みの環境（旧来のセットアップから移行してきた環境や、
`[bootstrap.packages]` に無い formula の依存として過去に入っていた場合など）だと、mise が
管理していないファイルがそのパスに既に存在するためリンクに失敗する。

```text
mise ERROR cannot link xz: these files already exist and were not
 created by mise or brew:
  /opt/homebrew/bin/unxz
  ...
Remove or rename them, then re-run `mise bootstrap packages apply`
```

対応手順（以下は `xz` を例にしているだけで、実際は衝突したパッケージ名に読み替える）:

1. エラーメッセージ冒頭に出ているパッケージ名（上記例では `xz`）を確認する
2. そのパッケージに依存している他の formula がいないか確認する
   ```sh
   brew uses --installed xz
   ```
3. 出力を見てアンインストール可否を判断する
   - 空（誰も依存していない）→ そのままアンインストールして問題ない
     ```sh
     brew uninstall xz
     ```
   - 何か出力される（例: `ffmpeg`）→ その formula を real brew に残す必要があるか確認する
     - 残す必要が無い／その formula ごと mise 管理に移行してよいなら、依存元も対象も
       まとめて指定してアンインストールする（`--ignore-dependencies` は依存チェックを
       スキップして対象だけを消すフラグで、依存元は自動では消えない。依存元を残したまま
       これを使うと依存元が壊れるので、依存元も一緒に指定すること）
       ```sh
       brew uninstall ffmpeg xz
       ```
     - 残す必要がある（real brew 側で使い続けたい）なら、この formula は mise 化を見送り
       `[bootstrap.packages]` から外すか、下記「real brew から mise bootstrap への本格移行」の
       手順で依存元ごと退避するかを検討する
4. アンインストールした場合は再度 bootstrap を実行する（mise 管理下でクリーンに再導入・リンクされる）
   ```sh
   mise bootstrap packages apply
   ```
5. 別のパッケージで同様のエラーが出た場合は 1〜4 を繰り返す

### real brew から mise bootstrap への本格移行（共有依存の衝突対応）

mise brew も real brew も同じ `/opt/homebrew` prefix を使う。`config.mac.toml` の
`[bootstrap.packages]` に列挙した formula を real brew 側でも個別に入れっぱなしにしていると、
`openssl@3` / `ca-certificates` / `json-c` のような共有依存を real brew が掴んだままになり、
mise 側がリンクできず前述の `cannot link` エラーになる。real brew 中心の環境から mise bootstrap
管理へ本格的に切り替える場合は、以下の手順で real brew 側から該当 formula と共有依存を退避させて
から bootstrap を実行する。

#### Phase 1. ブロッカー・移行対象を real brew から抜く

```sh
# ブロッカーになりがちな formula と、mise(brew:) に持たせる formula（＝ config.mac.toml の
# [bootstrap.packages] と同じ顔ぶれ）をまとめて real brew から外す
brew uninstall cocoapods ttyd git gnupg tig colordiff tree ffmpeg goaccess ugrep \
  coreutils findutils gnu-sed grep blueutil pinentry-mac silicon

# 孤立した共有依存を一掃（openssl@3 / ca-certificates / json-c / gettext / glib / cairo など）
brew autoremove
```

`brew uninstall` で `... is required by <X>` と出たら、`<X>` が「まだ real brew に残す何か」
なのでメモしておく（後続の判定に使う）。

#### Phase 2. 受け入れテスト

```sh
brew list --formula    # real brew に残った formula 一覧
```

後始末（★ここを飛ばすと bootstrap で再度 `cannot link` になる）:

```sh
# 古い openssl@3 の残骸を消す（autoremove は最新版しか消さない）
brew uninstall --force openssl@3
brew cleanup

# 残った設定ファイルを消す（これが最重要）
rm -rf /opt/homebrew/etc/openssl@3 /opt/homebrew/etc/ca-certificates
```

`/opt/homebrew/etc/ca-certificates/cert.pem` や `openssl@3/*` の設定ファイルが残っていると、
mise brew が自前の `ca-certificates` / `openssl@3` を導入して `cert.pem` を link しようとした際に
「file exists」で再び `cannot link` になる（本移行手順で最初に踏みやすいエラー再発ポイント）。

#### Phase 3. mise brew で入れ直す

```sh
mise bootstrap packages apply --yes
mise install --jobs=2
```

#### 注意点（共有 prefix の宿命）

mise brew も real brew も同じ `/opt/homebrew` prefix を使うため、Phase 2 でブロッカーを抜けても、
その後 real brew 側で `brew upgrade` / `brew doctor` / `brew cleanup` を走らせると、mise が張った
リンクを「見知らぬリンク」とみなして触ってしまう可能性がある。real brew は cask（GUI アプリ）用途
に限定して使い、`brew cleanup` は慎重に実行すること。

### cask（brew-cask:）

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

実行時に遭遇しうる代表的なメッセージ:

- `WARN brew-cask:<name>: multiple Caskroom versions found; reinstall to reconcile` →
  mise の**警告**（apply 自体は続行される）。`brew cleanup <name>` や
  `brew reinstall --cask <name>` を試しても消えないことがあり（実機で確認済み）、
  そのとき `ls -la <prefix>/Caskroom/<name>/` / `.../.metadata/` を見ても実際には
  バージョンディレクトリが1つしか無いことがある（= ディスク上は正常）。つまり mise 側の
  cask バージョン検出ロジックが誤検知している false positive の可能性が高い。ユーザー側で
  直せる問題ではなさそうなので、実害が無い限り（apply が止まらない限り）無視して構わない。
- `ERROR brew-cask:<name>: unsupported artifact type <type>`（例: `command_wrapper`、
  `postflight_steps`） →
  その cask の定義が mise の brew-cask バックエンド未対応の artifact 種別（`app`/`pkg`/
  `binary` 等の主要な型以外）を使っている場合の**エラー**。これは他の cask の警告と違い
  `mise bootstrap packages apply` 全体を中断させる。該当パッケージは
  `[bootstrap.packages]` から外し、`mise run bootstrap:mac-packages`
  （`dot_config/mise/tasks/bootstrap-mac.toml`）側で `brew install --cask <name>` する
  例外パッケージとして扱う（本リポジトリでは firefox / inkscape がこれに該当する。
  zoom は cask artifact 種別の問題ではなく private ホスト限定で使うための例外。
  詳細は `dot_config/mise/tasks/bootstrap-mac.toml` のコメント参照）。
- `ERROR brew-cask:<name>: failed to run postflight`
  （``Error: cask uses `auto_updates`, which mise's cask shim does not support``） →
  cask が自前の自動更新機能（`auto_updates true`）を宣言している場合、mise の cask シム
  （postflight を実行する portable-ruby スクリプト）がそれを未対応としてエラーになる。
  これも `mise bootstrap packages apply` 全体を中断させる**エラー**。上記の
  unsupported artifact type と同様に `[bootstrap.packages]` から外し
  `mise run bootstrap:mac-packages` 側の例外パッケージとして扱う
  （本リポジトリでは docker-desktop / keycastr / termius / thunderbird がこれに該当する。
  後者3つは private ホスト限定のため `HOST_ENV` で判定して work ホストではスキップする）。
- パスワードプロンプトで**止まって見える**（エラーは出ない） →
  cask のインストーラが `pkg`（Apple 標準の installer 形式）で、システムレベルの
  コンポーネント導入に sudo を要求する場合、`.chezmoi.toml.tmpl` の post-apply hook
  （非対話実行）の途中で気づかれにくいパスワードプロンプトが挟まりハングしているように
  見える。エラーではないのでパスワードを入力すれば進むが、post-apply hook を無言のまま
  完走させたい場合は該当パッケージを `[bootstrap.packages]` から外し
  `mise run bootstrap:mac-packages` 側の例外パッケージとして扱う（ユーザーが明示的に
  対話実行するタスクなので sudo プロンプトが出ても想定内になる。本リポジトリでは
  google-drive / tailscale-app がこれに該当する。いずれも private ホスト限定のため
  `HOST_ENV` で判定して work ホストではスキップする）。
- EULA 同意プロンプトで**止まって見える**（エラーは出ない） →
  cask のインストーラが利用許諾（EULA）への同意を求めるページャー表示を挟む場合、
  上記のパスワードプロンプトと同様に非対話実行の post-apply hook で気づかれにくく止まる。
  該当パッケージは `[bootstrap.packages]` から外し `mise run bootstrap:mac-packages`
  側の例外パッケージとして扱う（本リポジトリでは omnidisksweeper がこれに該当する。
  private ホスト限定のため `HOST_ENV` で判定して work ホストではスキップする）。
- `ERROR brew-cask: app artifact '<Name>.app' was not found` →
  ダウンロード/展開した中に期待する `.app` が見つからない場合の**エラー**（根本原因未確認）。
  これも `mise bootstrap packages apply` 全体を中断させる。他の unsupported artifact type
  と同様に `[bootstrap.packages]` から外し `mise run bootstrap:mac-packages` 側の例外
  パッケージとして扱う（本リポジトリでは raycast がこれに該当する。実 brew では問題なく
  インストールできることを確認済み）。
- `ERROR failed to fetch Homebrew cask '<tap>/<name>' directly. ... HTTP status client
error (404 Not Found)` → サードパーティ tap が Homebrew API メタデータ
  （`api/cask/<token>.json`）を公開していない場合のエラー。詳細は次項
  「サードパーティ tap の注意」参照（本リポジトリでは opencode-bar がこれに該当する）。

### サードパーティ tap の注意

`brew:`/`brew-cask:` でサードパーティ tap（例: `owner/tap/formula`）を使うには、その tap が
Homebrew API メタデータ（`api/formula/<name>.json` / `api/cask/<token>.json`）を実際に
公開している必要がある（`brew tap-new` が生成する GitHub Actions で自動生成されるのが典型）。
古い/小規模な tap では未対応なことがあり、その場合 `mise bootstrap packages apply` は
インストールできずに失敗する。

このリポジトリでは `thock`（`kamillobinski/thock`）について API メタデータの公開有無を
確認できなかったため、`[bootstrap.packages]` には移行せず `mise run bootstrap:mac-packages`
（実 `brew install`）のまま残している。`opencode-bar`（`opgginc/tap`）は
実際に `mise bootstrap packages apply` を実行して `api/cask/opencode-bar.json` が
404 になることを確認したため、同様に `bootstrap:mac-packages` 側に残した。
いずれも `brew tap` を先に打たず `brew install owner/tap/<name>` の完全修飾名で
インストールしている（Homebrew の tap trust: `brew tap` 後の短縮名インストールは
未信頼 tap で失敗しうるが、完全修飾名はその項目単体を暗黙に信任するため安全）。
**`.chezmoi.toml.tmpl` の post-apply hook は `mise bootstrap packages apply` の失敗を
fatal 扱いする**ため、未確認の tap を安易に `[bootstrap.packages]` に入れると、hook 全体を
壊すリスクがある。追加する場合は先に `mise bootstrap packages apply --dry-run` で個別に
検証してから。
