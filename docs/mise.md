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
4. `[dotfiles]` — dotfile 配置
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
mise bootstrap packages apply <manager>:<package>

# [bootstrap.packages] に追加して導入する
mise bootstrap packages use <manager>:<package>
```

`status`/`apply`/`upgrade`/`prune` は既に読み込まれている `[bootstrap.packages]` に対して
動くが、`use`/`import` は設定ファイルへの**書き込み**コマンドで、
`--path`（または `-g`）を指定しない限り**カレントディレクトリのローカル `mise.toml`**に書く
（デプロイ先 `~/.config/mise/config.mac.toml` にも、まして dotfiles リポジトリ側の source
（`~/dotfiles/config-mac/mise/config.mac.toml`）にも自動では書かれない）。このリポジトリは
「常に dotfiles リポジトリ（`~/dotfiles`）側の source を編集し、`[dotfiles]` で配る」
ルールなので、`use`/`import` を使うときは `~/dotfiles` で
`--path config-mac/mise/config.mac.toml` を明示するか、素直に
`~/dotfiles/config-mac/mise/config.mac.toml` を直接編集する方が確実。

```sh
# 状態確認（read-only。何も変更しない）
mise bootstrap packages status
mise bootstrap packages status --missing   # 未同期なら exit 1（CI/hook 向け）

# 実際に導入する
mise bootstrap packages apply
mise bootstrap packages apply --dry-run     # 何が実行されるかだけ確認
mise bootstrap packages apply --yes         # 確認プロンプトなし

# config に新しいパッケージを1個追加してすぐ導入（dotfiles リポジトリを明示）
cd ~/dotfiles
mise bootstrap packages use brew-cask:slack --path config-mac/mise/config.mac.toml
mise bootstrap dotfiles diff && mise bootstrap dotfiles apply

# 更新
mise bootstrap packages upgrade

# 設定にない・削除された formula を掃除（cask は未対応。後述）
mise bootstrap packages prune --dry-run
```

zabrze abbr（`config/zabrze/mise.toml`）: `mba` = apply、`mbu` = use、`mbs` = status。

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

1. 上記の出力を見ながら `config-mac/mise/config.mac.toml`（dotfiles リポジトリの source）に
   `"brew-cask:<token>" = "latest"` を追記し、`mise bootstrap dotfiles apply` でデプロイする。
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

- `ERROR brew-cask:<name>: Homebrew metadata exists, but no installed Caskroom version was found` →
  mise 2026.8.14 が追加した Homebrew 管理 cask の健全性チェックで、
  `<prefix>/Caskroom/<name>/.metadata` は存在するが、同じディレクトリにバージョン
  ディレクトリが1つもない場合に出る。`/Applications/<Name>.app` の有無はこの判定条件に
  含まれないため、このメッセージだけから「アプリが Caskroom を消した」とは判断できない。
  まず削除せずに実体を確認する:

  ```sh
  caskroom="$(brew --prefix)/Caskroom/ghostty"
  find "$caskroom" -maxdepth 2 -print
  ls -ld /Applications/Ghostty.app
  brew list --cask --versions ghostty
  ```

  修復して mise 管理へ揃えるには、いったん Homebrew の管理情報を復元して
  通常 uninstall した後、mise から再導入する。`--zap` は設定も削除するため使わない:

  ```sh
  brew install --cask --force ghostty
  brew uninstall --cask ghostty
  MISE_ENV=mac mise bootstrap packages apply brew-cask:ghostty
  ```

  参考: [mise #12346](https://github.com/jdx/mise/pull/12346),
  [Homebrew の Ghostty 1.3.1 更新](https://github.com/Homebrew/homebrew-cask/commit/2fbbe9b9838c50e6a7640b4f7cfb892479f5303b)

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
  （`config-mac/mise/tasks/bootstrap-mac.toml`）側で `brew install --cask <name>` する
  例外パッケージとして扱う（本リポジトリでは firefox / inkscape がこれに該当する。
  zoom は cask artifact 種別の問題ではなく private ホスト限定で使うための例外。
  詳細は `config-mac/mise/tasks/bootstrap-mac.toml` のコメント参照）。
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

# chezmoi ↔ mise dotfiles 比較検討

[jdx (mise 作者) のブログ記事「Dotfiles that save themselves」(2026-09-07 公開)](https://jdx.dev/posts/2026-09-07-dotfiles-that-save-themselves/)
がきっかけで、本リポジトリの dotfiles 管理を chezmoi から mise の `[dotfiles]`
（`mise bootstrap dotfiles`）に寄せられないかを検討した記録。

## mise dotfiles 機能の概要（今回分かった範囲）

mise には `[dotfiles]` セクションと `mise bootstrap dotfiles` サブコマンド群があり、
`mise bootstrap` の実行フェーズの1つ（`plugins → packages → files → services → firewall
→ compose → repos → **dotfiles** → mise-shell-activate → macos defaults → …` の9番目）
として統合されている。

- **配置モード**: `symlink`（デフォルト。ディレクトリ丸ごとも可）/ `symlink-each`
  （ディレクトリ内の各ファイルを個別 symlink、対象ディレクトリの他ファイルは触らない）/
  `copy`（コピーして上書き）/ `template`（`template = "tera"` でテンプレートエンジンを
  通してレンダリング）の4種類。
- **設定はファイル名エンコーディングではなく TOML の宣言的キー**: chezmoi の
  `dot_`/`private_`/`executable_` のようなファイル名プレフィックス方式ではなく、
  `"~/.zshrc" = { source = "...", mode = "..." }` のようにターゲットパス（絶対パスまたは
  `~/` 始まり）をキーにした宣言で書く。
- **variants（ホスト別出し分け）**: `os` / `arch` / `profile` セレクタで同じターゲット
  パスに異なる内容を割り当てられる（chezmoi の `.tmpl` 内 `{{ if eq .chezmoi.os "darwin" }}`
  に相当する分岐を、テンプレートの中ではなく設定の外側で表現するイメージ）。
- **テンプレートエンジンは Tera**（chezmoi の Go template とは別物。書き直しが必要）。
  `os()` / `arch()` / `os_family()` で OS 判定、`env.HOME` / `get_env(name=..,
default=..)` で環境変数、`exec(command)`（`cache_key`/`cache_duration` でキャッシュ可）
  でシェルアウト、`path is file` / `is dir` / `is exists` でパス存在判定ができる。
  `status`/`diff`/`apply` はテンプレート出力（`exec()` 呼び出し含む）を評価して差分検知する。
  `--dry-run` は何も実行しない代わりに `exec()` を評価せず `(if changed)` 扱いになる。
- **「target → source」の逆方向同期（ブログの "save themselves" の核心と推測される機能）**:
  `mise bootstrap dotfiles track ~/.zshrc` で「デプロイ先を直接編集する」運用を開始でき、
  `mise bootstrap dotfiles add --changed` で変更されたファイルをまとめて soruce に取り込める。
  `history` サブコマンドでチェックポイント（変更履歴）を辿れ、`[history.encryption].recipients`
  で履歴の暗号化もできる模様。chezmoi の「source を編集して apply で配る」片方向モデルとは
  逆に、「配置済みファイルを直接触ってもよく、mise が変更を検知して source 側に吸い上げる」
  運用を前提にしている点が最大の思想的な違い。
- **暗号化**: dotfiles エントリに `encrypt = true` を付けると、source に保存する前に暗号化
  される（`[history.encryption].recipients` で受信者を指定、age ベースと推測）。ただし
  chezmoi のような「パスワードマネージャー CLI を呼ぶ組み込みテンプレート関数
  （`bitwarden`/`bitwardenFields`/`onepassword`/`pass`/`keyring` 等）」に相当するものは
  ドキュメント上見つからず、`exec()` で自前にラップする必要がありそう。
- **フック**: `mise bootstrap` 全体に `pre-dotfiles`/`post-dotfiles` フェーズフックがあり
  （`[bootstrap.hooks.pre-dotfiles]` 等）、`mise bootstrap dotfiles apply` の前後に任意の
  シェルコマンドを挟める。chezmoi の `run_once_`/`run_onchange_` のような「ファイル単位の
  マーカー管理された一度きり/変更時実行スクリプト」という単位ではなく、dotfiles フェーズ
  全体を挟む前後フックという粒度になる。
- **Windows**: Developer Mode 有効時は本物のファイルシンボリックリンクを作成し、権限が
  無い場合は copy にフォールバックする。`symlink-each` は常にコピー、ディレクトリの
  symlink はジャンクションを使う、との記載がある。
- **既知の制約として書かれている点**: root 権限なしでは root 所有ファイル（`/etc/hosts` 等）
  は管理不可、厳密な JSON/XML の「ブロック編集」は非対応、symlink エントリの衝突解決には
  `--force` が必須、グローバル設定でのトラッキングのみサポート、など。
- 旧 `mise dotfiles` コマンドは deprecated で 2028.2.0 で削除予定。現行は
  `mise bootstrap dotfiles <subcommand>` を使う。

## 全体比較表

| 観点                        | chezmoi                                                                                                                                  | mise `[dotfiles]`                                                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| データモデル                | source dir が唯一の真実。`apply` で片方向にデプロイ                                                                                      | source（`dotfiles.root`）＋ 独自の履歴/チェックポイントストア。`track`/`add --changed` で配置先→source の逆流も可           |
| ファイル属性の宣言方法      | ファイル名プレフィックス（`dot_`/`private_`/`executable_`/`exact_`等）                                                                   | TOML キー＋`mode`。パーミッション/実行属性の明示的な宣言は未確認（ドキュメントに記載なし）                                  |
| テンプレートエンジン        | Go template（`text/template` 拡張）。`.tmpl` サフィックスで判定                                                                          | Tera（Jinja2 系）。`template = "tera"` で明示指定。**別言語なので既存 `.tmpl` は書き直し**                                  |
| OS/ホスト分岐               | テンプレート内 `{{ if eq .chezmoi.os "darwin" }}` 等 + `.chezmoiignore` の条件付き glob                                                  | `os()`/`arch()`/`os_family()` 関数 + エントリ単位の `variants`（`os`/`arch`/`profile`）セレクタ                             |
| ディレクトリ丸ごと除外      | `.chezmoiignore` に glob パターンで一括記述可能                                                                                          | エントリ単位の設定になる想定（glob 一括除外の仕組みは未確認）                                                               |
| フック                      | `run_once_*`/`run_onchange_*`（コンテンツハッシュで再実行判定）+ `hooks.apply.pre/post`（任意の複雑な bash）                             | `[bootstrap.hooks.pre-dotfiles]`/`post-dotfiles`（dotfiles フェーズ全体を挟む粒度）                                         |
| 差分プレビュー              | `chezmoi diff`                                                                                                                           | `mise bootstrap dotfiles diff`                                                                                              |
| 適用の安全性                | `apply` で決定的に収束。衝突時は対話 or `--force`                                                                                        | `status`/`diff`/`apply` の3段階。デフォルトは衝突拒否、`--force-dotfiles` で上書き                                          |
| 逆方向同期（配置先→source） | 無し（source を直接編集するのが正）。ただし `chezmoi edit` で source を開いて即座に反映は可能                                            | あり（`track`/`add --changed`/`history`）。ブログの主眼と推測される新機能                                                   |
| バージョン履歴              | git（source dir 自体が git repo）                                                                                                        | git（source dir）に加え、mise 独自の checkpoint/history ストアが並走する模様                                                |
| 暗号化・秘密情報            | 組み込みテンプレート関数でパスワードマネージャー多数連携（bitwarden/1Password/pass/keyring等） + 外部ツール（本リポジトリは `fnox`）併用 | エントリに `encrypt = true` + `[history.encryption].recipients`（age 系）。パスワードマネージャー連携の組み込み関数は未確認 |
| 外部ファイル取得            | `.chezmoiexternal.toml`（URL/アーカイブから取得・展開）                                                                                  | 相当機能は未確認                                                                                                            |
| CI 再現性・実績             | 10年以上の実績、本リポジトリで GitHub Actions 上の apply 検証が既に確立済み                                                              | dotfiles 機能自体がここ最近の新機能。実績・エコシステム記事は少数（今回参照できたブログ2本のみ）                            |
| ネイティブ Windows 対応     | Go 製、Windows ネイティブで動作。symlink 権限問題は同様に発生                                                                            | Rust 製、Windows ネイティブで動作。Developer Mode 時のみ real symlink、それ以外は copy フォールバック                       |
| bootstrap 全体との統合      | chezmoi 単体はパッケージ管理等を持たず、本リポジトリでは mise の `[bootstrap.packages]` 等と併用（post-apply hook で連携）               | `[dotfiles]` は `mise bootstrap` の1フェーズとして最初から統合済み（`[tools]`/`[bootstrap.packages]` と同じ設定ファイル内） |
| 学習コスト                  | 独自の命名規則・テンプレート関数を新規に覚える必要                                                                                       | 本リポジトリは既に mise 濃度が高い（`[bootstrap.*]` を多用）ため、設定ファイルの置き場所という意味では親和性が高い          |

## 本リポジトリの chezmoi 利用機能の棚卸しと mise 代替可否

実際にこのリポジトリが使っている chezmoi の機能を1つずつ洗い出し、mise `[dotfiles]` で
代替できそうかを評価する。

| 機能                                                                  | 本リポジトリでの実例                                                                                                                                         | mise `[dotfiles]` で代替できるか                                                                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dot_`/`private_`/`executable_`/`exact_` 命名規則                     | `local/bin/executable_*`（実行属性）、`config/rio/private_config.toml.tmpl`（0600相当）、`exact_dot_rulesync`（ディレクトリを厳密同期）                      | ⚠️ ドキュメント上パーミッション/実行属性の宣言方法が確認できず。`exact`（管理外ファイルを削除して厳密一致させる）挙動も未確認。要検証                                                                                                                                                                                                                           |
| `.tmpl`（Go template）による OS 分岐・シェルアウト                    | `dot_zshenv.tmpl`（`{{ if (lookPath "brew") }}`、`{{ output "mise" "activate" "zsh" "--shims" }}`）、`config.tmpl`（git/ghostty/alacritty 等）、計11ファイル | ⚠️ Tera で同等のことは可能（`os()`、`exec()`）だが **Go template → Tera の全面書き換えが必須**。`lookPath` は `exec("command -v brew")` 相当で代替、`output` は `exec()` で代替                                                                                                                                                                                 |
| `.chezmoiignore` の OS 条件付き glob 除外（`**/*mac*`/`**/*win*` 等） | ファイル種別・プラットフォームごとの一括除外                                                                                                                 | ⚠️ variants（`os` セレクタ）はエントリ単位。glob で一括除外する仕組みは未確認。エントリ数が多いこのリポジトリでは冗長になる可能性                                                                                                                                                                                                                               |
| `run_once_install-mise_mac.sh` / `run_once_setup.sh`                  | 初回のみ実行するセットアップスクリプト                                                                                                                       | ⚠️ `pre-dotfiles`/`post-dotfiles` フックは毎回走る前提。「初回だけ」を表現するには自前でマーカーファイル判定を書く必要があり、chezmoi の組み込み挙動より一段複雑になる                                                                                                                                                                                          |
| `run_onchange_*.sh.tmpl`（内容ハッシュをコメントに埋め込み変更検知）  | `run_onchange_mac.sh.tmpl`/`run_onchange_windows.sh.tmpl`/`run_onchange_copy.sh.tmpl`                                                                        | ✅/⚠️ `copy` モードの dotfiles エントリ自体が「内容が変わったときだけ書き込む」収束的な動きをするため、**単純なファイルコピーの用途はむしろ mise 側がシンプルになりうる**。ただし「WSL→Windows ネイティブパスへコピー」のような複雑な条件分岐ロジックは自前の hook スクリプトとして残る                                                                         |
| `hooks.apply.post` の複雑なオーケストレーション                       | PATH 設定、mise 自己更新、`bootstrap packages status/apply` の HOST_ENV 分岐、gh auth フロー、APM/rulesync のハッシュマーカー制御（約140行の bash）          | ✅ `[bootstrap.hooks.post-dotfiles]`（または `[bootstrap.hooks.final]`）に同等の bash をほぼそのまま移植可能。任意コマンドを実行できる点は chezmoi の hook と本質的に同じ                                                                                                                                                                                       |
| WSL 上で Windows ネイティブアプリの設定を `$APPDATA` 配下へ複写       | `run_onchange_windows.sh.tmpl`（AutoHotkey/Alacritty/Rio/VSCode/Claude Desktop 設定を `/mnt/c/...` へ複写）                                                  | ⚠️ mise の `os()` は WSL 上でも `"linux"` を返すと推測され、chezmoi 同様「OS 判定だけでは WSL 特有の複写要件を表現できない」制約は変わらない。dotfiles エントリのターゲットに `/mnt/c/...` の絶対パスを直接指定すればモード自体は動きそうだが、"変更があったときだけ" の判定や WSL 検出ロジックは結局 hook 側に自前で残ることになり、根本的な簡素化にはならない |
| `[bitwarden] unlock = "auto"`、editor/pager/scriptEnv 設定            | chezmoi CLI 自体の UX 設定（`chezmoi edit` の挙動、delta pager 等）                                                                                          | ❌ mise dotfiles は別 UX（`track`/`apply`/`history`）のため直接の対応物なし。実質的に不要になる（またはワークフローが変わる）                                                                                                                                                                                                                                   |
| GitHub Actions での `chezmoi apply` の CI 検証（test-linux/test-mac） | `.chezmoiignore` に一時追記して bitwarden 依存の `.czrc` を除外しつつ apply を検証                                                                           | ⚠️ `mise bootstrap dotfiles apply --dry-run`/`status` で同種の CI 検証は組めそうだが、実績のある chezmoi 版ワークフローを丸ごと作り直すコストが発生                                                                                                                                                                                                             |
| secret 解決（実体は fnox が担っている）                               | `config/fnox/config*.toml` + `bitwarden-sm`/`bitwarden` provider                                                                                             | ✅ ここは chezmoi 固有の機能ではなく fnox 側の責務なので、mise 化しても **無関係でそのまま使い続けられる**                                                                                                                                                                                                                                                      |

凡例: ✅ 代替可能・影響小　⚠️ 代替は可能そうだが書き直しコスト/未検証点あり　❌ 直接の対応物なし

## マルチプラットフォーム対応の詳細評価

ユーザーからの関心が高いポイントなので個別に整理する。本リポジトリが実際に扱っている
プラットフォームは **macOS / Linux（WSL2 Ubuntu）/ Windows ネイティブアプリ（WSL 越しに
`$APPDATA` 等へ配置）** の3系統。

1. **OS 判定そのもの**: chezmoi の `.chezmoi.os`（`darwin`/`linux`/`windows`）と mise の
   `os()`（`macos`/`linux`/`windows`）は機能的にほぼ等価。WSL 上では両方とも `linux` 判定
   になる（chezmoi にも WSL 専用の判定変数は無く、本リポジトリは `dot_zshenv.tmpl` 内で
   `scutil`/`hostname` から `HOST_ENV`（例: `mac`/`linux,work2`）を自前解決して
   `MISE_ENV` に流用している）。ここは**優劣なし**。
2. **ホスト別の出し分け**: chezmoi はテンプレート内の任意の Go template 条件分岐＋
   `.chezmoi.toml.tmpl` の `[data]`（本リポジトリでは未使用）で自由度が高い。mise の
   `variants`（`os`/`arch`/`profile`）はセレクタベースで宣言的だが、**任意の bash 条件式
   ほどの柔軟性は無さそう**（`HOST_ENV=mac,work2` のような複合ホスト識別子をキーにした
   出し分けは `profile` セレクタで表現できる可能性はあるが、ドキュメント上の実例が薄く未検証）。
3. **Windows ネイティブ symlink**: mise は Developer Mode 時のみ real symlink、それ以外は
   copy にフォールバックする点が明記されている。chezmoi も Windows では管理者権限や
   Developer Mode が絡む点は同様の制約を抱えており、**この軸でも優劣は大きくない**。
4. **WSL → Windows ホスト側ファイルシステムへの配置**（本リポジトリ最大の複雑ポイント）:
   `run_onchange_windows.sh.tmpl` は「Linux 上で走るが、宛先は `/mnt/c/Users/.../AppData`
   という Windows 側パス」という chezmoi の OS 判定の枠組みの外側にある要件を、素の bash
   ループで実装している。mise の `os()`/`variants` も同様に「実行環境の OS」までしか
   判定できないため、**この要件は mise 化してもテンプレート/variants だけでは解決せず、
   結局 hook 内の自前スクリプトとして残る**。dotfiles エントリのターゲットパスとして
   `/mnt/c/...` の絶対パスを直接指定すれば `copy` モードの適用自体は動きそうだが、
   「タイムスタンプ比較で更新分だけ複写」という現行ロジックの一部は dotfiles エントリの
   標準機能（変更検知して書き込む）に置き換えられる可能性がある一方、複数ソース→複数
   宛先のマッピング配列のような構造は素直に TOML 化しづらく、結果的に hook 側の bash が
   大きく残る。
5. **結論**: マルチプラットフォーム対応の**基礎体力（OS 判定・Windows symlink 制約）は
   ほぼ同等**。ただし本リポジトリの実際の難所は「WSL から Windows ネイティブアプリへの
   配置」という**どちらのツールの標準機能でもカバーしきれない領域**であり、mise に
   移行してもこの部分の複雑さ・自前ロジックはほぼそのまま残る。「mise なら
   マルチプラットフォーム対応がシンプルになる」という期待は、少なくとも本リポジトリの
   要件に関しては**過大評価**になりそう。

## 結論と実際の移行結果

上記の検討時点（2026-09-08 時点、mise 2026.9.2）では「今すぐの全面移行は時期尚早」と
一旦結論づけていたが、その後実機（実際の mise 2026.9.2 バイナリ）で `[dotfiles]` の
symlink/copy/template 各モード・variants・hooks を検証したところ、当初懸念していた
ギャップの多くが解消できることを確認できたため、方針を変更して**全面移行を実施した**。

実機検証で判明した主な訂正点:

- **パーミッション/実行属性**: chezmoi の `executable_`/`private_` プレフィックスに相当する
  TOML キーは無いが、`copy`/`template` モードは **source ファイル自身が Git 上で持つ
  パーミッションビット（実行属性・0600 など）をそのまま target にコピーする**。つまり
  `git update-index --chmod=+x` や `chmod 600` を source ファイルに対して行うだけで済み、
  特別な宣言は不要（むしろ chezmoi の命名規則より単純）。
- **`.chezmoiignore` 相当の一括除外**: `[dotfiles]` は完全な明示的許可リスト方式なので、
  そもそも「除外」という概念が要らない。配りたいファイルだけを列挙すればよい。
  OS 限定のファイル（chezmoi で `{{ else }}` 分岐により除外されていたもの）は、当初は
  mise のネイティブな `mise.<ENV>.toml` オーバーレイ機構（`MISE_ENV` に応じて自動マージ
  される、`config.mac.toml`/`config.linux.toml` と同じ仕組み）で `mise.mac.toml`/
  `mise.linux.toml` に振り分けていたが、後に `~/.config` を track mode へ移行した際に
  ほとんどが共通 `config/` へ吸収され、OS 限定で今も copy として残るのは
  mise 自体の tool/config pin（`mise.mac.toml`）と raycast・autohotkey の
  seed 元（`config-mac/`・`config-linux/`。詳細は後述の track/history の節）だけになった。
- **Go template → Tera の書き換え**: 実際にやってみると `{{ if eq .chezmoi.os "darwin" }}`
  → `{% if os() == "macos" %}` のような機械的な置換がほとんどで、11 ファイルの書き換えは
  数十分で完了した（`exec()` が `set -e` 相当で動くため、失敗しうるシェルコマンドは
  `|| true` で必ずガードする点だけが実質的なハマりどころだった）。
- **WSL→Windows ネイティブアプリへの配置**: これは想定通り `[dotfiles]` の対象外
  （`$HOME` 配下の宣言的配置という設計の範囲外）のままだったため、`mise run
dotfiles:sync-mac`/`dotfiles:sync-windows`（`tasks/dotfiles-sync.toml`）という
  **対話式タスク**として持ち越した。元の chezmoi `run_onchange_*.sh.tmpl` が持っていた
  y/n/d の対話プロンプトはそのまま踏襲している。

移行後のアーキテクチャ:

- dotfiles リポジトリ（`~/dotfiles`）を clone し、その中で `mise bootstrap` を実行する
  運用に変更（旧: `chezmoi init --apply <repo>`）。
- 全 dotfiles は repo 直下の `mise.toml`（共通）・`mise.mac.toml`（`MISE_ENV` 別。
  当時は `mise.linux.toml` もあったが、後の track mode 移行で不要になり削除した）の
  `[dotfiles]` に列挙し、`config/`・`local/` 等のプレーンなディレクトリ構成
  （`dot_`/`private_`/`executable_`/`exact_` の命名規則は廃止）から `$HOME` へ配布する。
- 旧 `.chezmoi.toml.tmpl` の `hooks.apply.post`（約140行の bash）は、mise 自体が
  `[bootstrap.packages]`/`[tools]` フェーズをネイティブに処理するようになった分だけ
  大幅に縮小し、`[bootstrap.hooks.pre-tools]`（gh 認証・GITHUB_TOKEN 付き mise install）・
  `[bootstrap.hooks.post-tools]`（APM/rulesync のハッシュマーカー制御）の2フックに整理した。
  mise 自体の self-update は `mise bootstrap` の外（`lefthook.yml` の `post-merge`）に切り出したため、
  bootstrap hook 側には残していない。
  - hook は `mise bootstrap` の実行時にしか発火しない（公式ドキュメント
    "Hooks run only during explicit `mise bootstrap` invocations." の通り）。
    `mise install` を単体で実行しても `pre-tools`/`post-tools` は一切走らない
    ——これは仕様通りで、gh 認証等が必要な場合は必ず `mise bootstrap` から
    実行する必要がある。
  - `pre-tools` は GITHUB_TOKEN 付きで `mise install` を明示的に呼ぶため、
    その直後に native の tools フェーズ（`mise install installs missing [tools]`）が
    もう一度走り、1 bootstrap あたり `mise install` は実質2回実行される。
    hook は子シェルプロセスであり、hook 内で export した環境変数は親プロセス
    （native フェーズ）へ伝播しないため、GITHUB_TOKEN を確実に渡すにはこの
    二重実行が唯一の手段（詳細は `mise.toml` の `pre-tools` コメント参照）。
    2回目は全ツール導入済みの冪等チェックのみで即座に完了するため、
    実処理としての無駄（再ダウンロード等）は発生しない。
- `run_once_setup.sh`（`~/.zshenv` シンボリックリンク作成）は不要になった。
  `~/.zshenv` 自体を `[dotfiles]` の1エントリとして直接配置している。

**残っている follow-up（今回は意図的にスコープ外にした）**:

- `config/zabrze/chezmoi.toml`（chezmoi コマンドの abbreviation 集）、
  `github:ryo246912/lazychezmoi`（chezmoi 用の lazygit 風 TUI。lazygit の
  custom command・tmux/zsh のツール選択ランチャー・nvim の `chezmoi_git_panel` から
  呼ばれている）は、chezmoi の CLI 自体（`chezmoi diff`/`chezmoi edit`/`chezmoi merge`
  等）を前提にした独自のワークフローツール群で、mise 側に直接の代替が無い。
  今回は `aqua:twpayne/chezmoi` を `[tools]` から外さず、これらは動作可能な状態のまま
  残した。「lazychezmoi 的な体験を mise 版として作るか」「素のリポジトリ checkout に対する
  汎用 git TUI で妥協するか」は別途判断が必要。

# mise dotfiles 基本的な使い方

`mise bootstrap dotfiles`（`[dotfiles]`）の実践的な使い方。以下は実際に mise 2026.9.2
バイナリで動作確認済み。旧 `mise dotfiles`（サブコマンドなし版）は deprecated
（2028.2.0 で削除予定）なので、必ず `mise bootstrap dotfiles` を使うこと。

## 設定の書き方

`[dotfiles]` はターゲットパス（`~/` 始まりか絶対パス）をキーにした宣言的な TOML。

```toml
[dotfiles]
"~/.zshrc" = { source = "config/zsh/.zshrc", mode = "copy" }
"~/.config/starship.toml" = { source = "config/starship.toml", mode = "copy" }
"~/.zshenv" = { source = "templates/zsh/.zshenv.tera", mode = "template", template = "tera" }
```

`source` は相対パスの場合、**その `[dotfiles]` を定義している設定ファイル自身のディレクトリ**
から解決される（`dotfiles.root` を設定しなくても動く。設定すればさらに source を
まとめられる）。カレントディレクトリではない点に注意。

## 4つの配置モード

| モード         | 動作                                                                                               |
| -------------- | -------------------------------------------------------------------------------------------------- |
| `symlink`      | source へのシンボリックリンクを作成（デフォルト）。ディレクトリ全体も可                            |
| `symlink-each` | ディレクトリ内の各ファイルを個別に symlink（対象ディレクトリの他ファイルは触らない）               |
| `copy`         | source の内容をコピー。**パーミッションビット（実行属性・0600 等）も source からそのまま引き継ぐ** |
| `template`     | `template = "tera"` を付けてテンプレートエンジンでレンダリング                                     |

パーミッションを変えたい実行可能スクリプトや秘密ファイルは、TOML 側に特別なキーを
書く必要はなく、**source ファイル自体に `chmod` しておけば `copy`/`template` が
そのまま反映する**（これは実機で `chmod 755`/`chmod 600` した source を copy させて
確認済み）。

### ディレクトリ単位で宣言する（ブランケットコピー）

`target` はファイルだけでなく**ディレクトリ**も指定でき、`copy`/`symlink` は
ディレクトリを渡すと中身ごと再帰的に配置する。**mise には chezmoi の `.chezmoiignore`
に相当する「ディレクトリ丸ごと配りつつ一部だけ除外する」機能は無い**（`ignore`/
`exclude` のようなフィールドを試したが実機で無視されるだけだった）。
`"~/.config" = { source = "config", mode = "copy" }` のように宣言すると、
**source ディレクトリに物理的に存在するファイルは何であれ、TOML に書いていなくても
全部コピーされる**。

本リポジトリではこれを逆手に取り、以下の方針でリポジトリのディレクトリ構成そのものを
「ブランケットコピーしてよい形」に揃えた（`~/.apm`・`~/.claude`・`~/.codex`・`~/.local` に
現在も採用中。**`~/.config` 自体は後に track mode へ移行しており、この節のパターンでは
なくなった**。track の詳細・具体的な現在の `~/.config` 内訳は前節「target → source
の逆方向ワークフロー」参照）:

- **配ってよいファイルだけを置く専用ディレクトリを決め**、`mise.toml`（共通）から
  `"~/.apm" = { source = "apm", mode = "copy" }` のように1行でまとめて配る。
  これで `[dotfiles]` は194行→11行（当時の `~/.config` 込みの数字）まで縮んだ。
- **テンプレート**（Tera）が要るファイルは配布元ディレクトリの外、`templates/` に隔離する
  （配布元ディレクトリ配下に置いたままだと、ブランケット copy が未レンダリングの
  `.tera` をそのまま巻き込んでコピーしてしまう不具合を実機で確認したため。`mode` が
  違うファイルは同じディレクトリに同居させられない）。
- **OS 限定で copy のまま配りたいファイル**は別ツリー（本リポジトリでは
  `config-mac/`・`config-linux/`）に隔離し、`mise.mac.toml`/`mise.linux.toml` 側から
  個別に `mode = "copy"` で宣言する。**共通ブランケット側と同じキーを OS 側で
  再宣言してはいけない**——「共通ブランケットのマージ」ではなく完全な**上書き**になり、
  共通側が一切配置されなくなる（同じキーが複数の merge される config ファイルに
  出てきたときの挙動として実機で確認済み。詳細は下記コラム参照）。ただし
  「同一キー = 上書き」に抵触するのはあくまで**全く同じキー**を再宣言した場合の話で、
  **より具体的な別キーなら、共通ブランケットの target ディレクトリと物理的に
  重なっていても、両方の `mode = "copy"` エントリの出力が破壊的な削除なしにそのまま
  共存する**ことを実機で確認済み。そのため OS 限定ファイルは 1 ファイルずつではなく、
  ディレクトリ単位でまとめて宣言してよい。今後そのディレクトリにファイルを追加しても
  `[dotfiles]` 側の追記が不要になる。
  **`~/.config` を track mode へ移行した現在の本リポジトリでは、このパターンで
  残っているのは mise 自体の tool/config pin（`config-mac/mise` → `mise.mac.toml`）
  だけ**。それ以外の OS 限定ファイル（raycast・autohotkey）は `[dotfiles]` の
  宣言的コピーではなく、track mode の節で述べた `[bootstrap.hooks.pre-dotfiles]`
  の一度きり seed（find+cp、`[dotfiles]` に書かない）で配る形に変わった——OS ごとに
  「常に収束させたい」ものではなく「初回だけ置いて、あとは手元編集の history に
  任せたい」ものだったため。`mise.linux.toml` はこの移行で対象が無くなり削除した。
- **絶対に配りたくないファイル**（旧 chezmoi の `.chezmoiignore` で丸ごと除外していた
  もの。例: `vscode`/`dbeaver`/`sidebery`/`rclone`/`karabiner-ts`）は `not_config/`
  に置く（このリポジトリではもともとこの用途の慣習的なディレクトリ名だったので流用した）。

> **同一キーの merge は上書き、別キーは並存する（実機で確認済みの挙動）**
>
> ある config ファイルに `"~/.foo" = {...}` を書き、別の merge される config ファイルに
> **同じキー** `"~/.foo" = {...}` を書くと、後者だけが有効になり前者は消える
> （片方が勝つ、足し算にならない）。一方、`"~/.foo" = {...}`（ブランケット）と
> `"~/.foo/bar" = {..., mode="template"}`（specific、別キー）を**同じファイル**に
> 書いた場合はどちらも適用される（ブランケットが丸ごとコピーした後、specific な
> キーが該当ファイルだけレンダリングし直す）。ただし前述のとおり、ブランケット側の
> source に `.tera` の生ファイルが物理的に存在していれば、それも未レンダリングのまま
> 一緒にコピーされてしまう点は変わらない。だからテンプレートは物理的に隔離するのが
> 結局いちばん安全（この規則は copy 同士に限らず、track と copy が入れ子になる場合にも
> 同様に成り立つ。前節参照）。

このパターンが使えるのはリポジトリの物理レイアウトを「配ってよいものと配ってはいけない
ものが同じディレクトリに混在しない」ように整理できるときに限る。既存の chezmoi リポジトリを
移行する場合、最初から完全に整理された状態にはならないことが多いので、
「まずは1ファイルずつ個別宣言 → 均質なディレクトリだけ集約 → 最終的に例外を
物理的に追い出してブランケット化」の順で段階的に進めるのが安全（このリポジトリも
実際にその3段階を踏んだ）。

## テンプレート（Tera）

Go template（chezmoi）とは別のエンジンなので構文の書き直しが要る。

```tera
{% if os() == "macos" %}
  helper = osxkeychain
{% else %}
  helper = manager
{% endif %}
```

主な関数:

- `os()` → `"macos"` / `"linux"` / `"windows"`、`arch()`、`os_family()`
- `env.HOME` / `get_env(name="X", default="Y")` — 環境変数
- `exec(command="...")` — シェルアウトして標準出力を文字列として埋め込む。
  **`set -e` 相当で動くため、失敗しうるコマンドは必ず `|| true` 等でガードする**
  （例: `exec(command="command -v brew 2>/dev/null || true")`。ガードを忘れると
  `mise bootstrap dotfiles status`/`diff`/`apply` が軒並み `failed to render template`
  で失敗する）
- `path is file` / `is dir` / `is exists` — パス存在判定
- `exec()` は `status`/`diff`/`apply` では実行されるが、`--dry-run` では実行されず
  `(if changed)` 扱いになる（副作用のあるコマンドを `exec()` に書かないこと）

## OS 限定のファイル

chezmoi の `.chezmoiignore` OS 条件分岐に相当する「このファイルは特定 OS でだけ配る」
は、`[dotfiles]` エントリの中では表現できない（同一キーへの複数エントリや `os`
フィールドは whole-file エントリでは未対応 — `variants` フィールドは `mode = "track"`
専用）。代わりに mise ネイティブの `mise.<ENV>.toml` オーバーレイ（`MISE_ENV` に応じて
自動マージされる設定ファイル）に振り分ける。本リポジトリでは:

```sh
mise.toml        # 共通（全 OS で配る）
mise.mac.toml     # MISE_ENV に "mac" を含むときだけ追加で読まれる
mise.linux.toml   # 存在すれば MISE_ENV に "linux" を含むときだけ追加で読まれる
                  # （本リポジトリでは現在 linux 固有の [dotfiles] entry が無いため未使用）
```

同一ファイル内で OS ごとに**内容の一部だけ**変えたい場合（1ファイルは常に配るが
中身が違う）は、この振り分けではなく Tera テンプレートの `{% if os() == ... %}` を使う。

## よく使うコマンド

```sh
# 現在の状態を確認（read-only。テンプレートは実際にレンダリングして差分検知する）
mise bootstrap dotfiles status
mise bootstrap dotfiles status --missing   # 未同期なら exit 1（CI 向け）

# 差分を表示
mise bootstrap dotfiles diff

# 適用（デフォルトは衝突を拒否する。--force で強制上書き）
mise bootstrap dotfiles apply
mise bootstrap dotfiles apply --dry-run
mise bootstrap dotfiles apply --force --yes

# 特定 target だけ適用
mise bootstrap dotfiles apply "~/.zshrc"

# 管理対象を外す（target のファイルは残したまま [dotfiles] エントリだけ削除する場合は
# 手動で設定を編集。target のファイル自体を消して未管理に戻す場合）
mise bootstrap dotfiles unapply "~/.zshrc"
```

`mise bootstrap`（`[dotfiles]` 単体でなく bootstrap 全体）を実行すると、
`packages → ... → repos → dotfiles → shell-activate → ... → tools → ...` の
1フェーズとして自動的に `mise bootstrap dotfiles apply` 相当が実行される
（`pre-dotfiles`/`post-dotfiles` フックで前後に処理を挟める）。

## 「target → source」の逆方向ワークフロー（track/save/history）

`[dotfiles]` の whole-file エントリ（symlink/copy/template）は「source を編集して
apply で配る」chezmoi と同じ片方向モデルだが、mise にはこれとは別に **配置済みファイルを
直接編集し、その変更を自動で記録する**運用（`mode = "track"`）もある。ブログ記事の
"self-saving" の核心はこちら。本リポジトリでは `~/.config`（apm/claude/codex/local は
主に tool 管理で history の恩恵が薄いため対象外）に採用した。

### 実機で判明した制約

- **track エントリは global config（`~/.config/mise/config.toml` 等）でしか有効にならない。**
  project config（このリポジトリの `mise.toml`）に書くと
  `tracking is enrolled from the global configuration only, ignoring entry`
  という warning とともに無視される（実機確認済み）。本リポジトリでは
  `config/mise/config.toml`（`~/.config/mise/config.toml` へ deploy される git source）に
  `"~/.config" = { mode = "track" }` を書くことで、通常の `[dotfiles]` copy と同じ
  「git で編集 → deploy」の流儀を保ったまま track を宣言している。
- **track には source からの初回配置（seeding）が無い。** 追跡対象が存在しない場合は
  「存在するようになったら追跡する」だけで待機し、内容を生成してはくれない
  （`mise bootstrap dotfiles track` を実行しても同様）。そのため、真新しいマシンでは
  何もデプロイされない。本リポジトリでは `[bootstrap.hooks.pre-dotfiles]`
  （`mise.toml` 参照）で `config/`（共通）と、OS 限定で残った
  `config-mac/raycast`・`config-linux/autohotkey` から `~/.config` へ
  「無いものだけ」を find+cp で seed してから track フェーズに入るようにしている。
  より宣言的な代替（`[dotfiles]` の copy/template mode、`[bootstrap.files]`/
  `[bootstrap.directories]`）は無いか公式ドキュメントで確認したが、いずれも
  「ディレクトリツリー一括・無ければ配置してあれば触らない」という条件を満たす
  仕組みは持たない（copy/template は常に source へ収束＝上書き、
  `[bootstrap.files]` はファイル単位の絶対パス宣言かつ常に内容収束）ため、
  hook 以外の書き方は無いという結論に至った（詳細は `mise.toml` のコメント参照）。
- **track 対象木の中に、より具体的なキーの copy entry を入れ子にしても安全に共存する。**
  `"~/.config" = track` と `"~/.config/mise" = copy` を同時に宣言した場合、
  `~/.config/mise` 配下は copy 側が排他的に管理し、それ以外の `~/.config` 配下は
  track 側が管理する（実機確認済み）。逆に、**同じ target path を track と copy の
  両方でカバーすると、copy 側の再適用が track 側のライブ編集を無言で消す**
  （実機で確認済みの破壊的挙動）。本リポジトリで `~/.config/mise`
  （mise 自体の tool/config pin。git 側を正として常に収束させたい）だけを
  copy のまま残し、それ以外を track にしているのはこのため。
- **`status`/`diff`/`apply` は track エントリに対してはほぼ no-op**（state は常に
  `applied` ではなく `tracked` になる）。差分レビューは `dotfiles:diff`
  （`tasks/dotfiles.toml`）ではなく次項の `history diff` を使うこと。

### 使い方

```sh
# 変更を今すぐチェックポイントとして保存する（mise run dotfiles:history-save）
mise bootstrap dotfiles save

# 変更履歴を辿る（mise run dotfiles:history-log）
mise bootstrap dotfiles history

# working tree と最新 checkpoint の差分（行単位、mise run dotfiles:history-diff で delta へ pipe）
mise bootstrap dotfiles history diff --patch

# 2つの checkpoint 間の差分
mise bootstrap dotfiles history diff 11 12 --patch

# 巻き戻す
mise bootstrap dotfiles rollback ~/.config/some/file
mise bootstrap dotfiles undo
```

自動保存（変更のたびに自動でチェックポイントを取る）は
`[bootstrap.services.mise-history] builtin = "history-watch"`（`mise.toml` 参照）で
宣言済みで、`mise bootstrap` の一部として自動的に有効化を試みる
（内部的には `mise bootstrap services apply` 相当。systemd user manager が無い環境
（一部のコンテナ等）では skip されるだけで bootstrap 全体は失敗しない）。
有効化されていない状態では `mise bootstrap dotfiles save` を手動実行するまで
記録されない。

### 複数マシン間での history 同期（origin）

checkpoint の実体はデフォルトでは各マシンのローカルにしか無い。複数マシンで
共有したい場合は、このリポジトリ（`ryo246912/dotfiles`）とは**別の**専用 git
リポジトリを用意し、各マシンで一度だけ接続する（`[history.origin]` として
machine-local に書き込まれる設定で、git 管理される `mise.toml`/`config/mise/config.toml`
側には残らない。マシンごとに実行が必要）。

```sh
mise bootstrap dotfiles origin set https://github.com/<you>/<setup-repo>.git
```

未接続の場合は `mise bootstrap dotfiles status` の末尾に
`Setup repository: none` と表示される。

## ハマりどころ

- `add`/`edit` はデフォルトで**グローバル設定**（`~/.config/mise/config.toml`）に書く。
  このリポジトリのように「常に dotfiles リポジトリ側の source を編集する」運用では、
  `--local`（または `--path <file>`）を必ず指定すること。指定を忘れると
  意図せずグローバル設定に直接エントリが追加される。
- `template` モードの `status`/`diff`/`apply` はテンプレートを実際にレンダリングする
  （`exec()` も実行される）。CI で secret に依存するテンプレートを検証する場合は、
  対象を `TARGET` 引数で絞るか、必要な環境変数だけ渡すこと。
- `mise bootstrap dotfiles apply` を単体で呼ぶ場合、hook の中で使う変数
  （`$MISE_PROJECT_ROOT` 等）はフック内では未設定になる。フック・タスク内で
  リポジトリの場所を参照したい場合は `$(pwd)` で解決するか、常にリポジトリ直下から
  実行する運用にする（本リポジトリの `[bootstrap.hooks.*]` はこの前提で書いている）。
