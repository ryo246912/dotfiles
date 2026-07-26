# mise bootstrap トラブルシューティング

`mise bootstrap packages apply`（`dot_config/mise/config.mac.toml` の `[bootstrap.packages]`
参照）は、宣言した brew パッケージの導入・リンクを mise が管理する仕組み。初回セットアップとは
別に、既存環境で発生しうる衝突の対処法をまとめる。

## brew で個別導入済みのパッケージと衝突する場合

すでに `brew install` で直接導入済みの環境（旧来のセットアップから移行してきた環境や、
`[bootstrap.packages]` に無い formula の依存として過去に入っていた場合など）だと、mise が
管理していないファイルがそのパスに既に存在するためリンクに失敗する。

```
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
     - 残す必要が無い／その formula ごと mise 管理に移行してよいなら、依存元も含めて
       アンインストールする（依存元を先に `brew uninstall <依存元>` で外してから対象を
       アンインストールする。まとめて外す場合のみ `--ignore-dependencies` を使う）
       ```sh
       brew uninstall --ignore-dependencies xz
       ```
     - 残す必要がある（real brew 側で使い続けたい）なら、この formula は mise 化を見送り
       `[bootstrap.packages]` から外すか、下記「real brew から mise bootstrap への本格移行」の
       手順で依存元ごと退避するかを検討する
4. アンインストールした場合は再度 bootstrap を実行する（mise 管理下でクリーンに再導入・リンクされる）
   ```sh
   MISE_ENV=mac mise bootstrap packages apply
   ```
5. 別のパッケージで同様のエラーが出た場合は 1〜4 を繰り返す

エラーメッセージが指す各ファイルを直接 `rm` して解決することもできるが、消し残しが出やすいので
`brew uninstall` でパッケージごと外す方が確実。openssl@3 / ca-certificates / json-c のような
共有依存まで巻き込む場合は、下記の「real brew から mise bootstrap への本格移行」を参照。

## real brew から mise bootstrap への本格移行（共有依存の衝突対応）

mise brew も real brew も同じ `/opt/homebrew` prefix を使う。`config.mac.toml` の
`[bootstrap.packages]` に列挙した formula を real brew 側でも個別に入れっぱなしにしていると、
`openssl@3` / `ca-certificates` / `json-c` のような共有依存を real brew が掴んだままになり、
mise 側がリンクできず前述の `cannot link` エラーになる。real brew 中心の環境から mise bootstrap
管理へ本格的に切り替える場合は、以下の手順で real brew 側から該当 formula と共有依存を退避させて
から bootstrap を実行する。

### Phase 1. ブロッカー・移行対象を real brew から抜く

```sh
# ブロッカーになりがちな formula（cocoapods は ruby gem, ttyd は libwebsockets/libevent を
# 道連れにする）と、mise(brew:) に持たせる formula（＝ config.mac.toml の
# [bootstrap.packages] と同じ顔ぶれ）をまとめて real brew から外す
brew uninstall cocoapods ttyd git gnupg tig colordiff tree ffmpeg goaccess ugrep \
  coreutils findutils gnu-sed grep blueutil pinentry-mac silicon

# 孤立した共有依存を一掃（openssl@3 / ca-certificates / json-c / gettext / glib / cairo など）
brew autoremove
```

`brew uninstall` で `... is required by <X>` と出たら、`<X>` が「まだ real brew に残す何か」
なのでメモしておく（後続の判定に使う）。

### Phase 2. 受け入れテスト（ここが成否の分かれ目）

```sh
brew uses --installed openssl@3      # ← ca-certificates を間接的に掴む全 formula
brew list --formula                  # real brew に残った formula 一覧
```

判定:

- `brew uses --installed openssl@3` が空（誰も掴んでいない）→ mise brew が `openssl@3` /
  `ca-certificates` を link できる状態。Phase 3 へ進む
- 何か残っていたら、その名前が真のブロッカー。formula 単位で「MacPorts/mise へ逃がす」か
  「real brew 併存に戻す」かを判断する
- `brew list --formula` は理想的には空（+ cask のみ残る）。cask は `brew uses` に出てこない
  ＝共有依存を掴んでいないので、そのまま real brew 管理で共存して問題ない

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

### Phase 3. mise brew で入れ直す

```sh
MISE_ENV=mac mise bootstrap packages apply --yes
mise install --jobs=2
```

### 注意点（共有 prefix の宿命）

mise brew も real brew も同じ `/opt/homebrew` prefix を使うため、Phase 2 でブロッカーを抜けても、
その後 real brew 側で `brew upgrade` / `brew doctor` / `brew cleanup` を走らせると、mise が張った
リンクを「見知らぬリンク」とみなして触ってしまう可能性がある。real brew は cask（GUI アプリ）用途
に限定して使い、`brew cleanup` は慎重に実行すること。
