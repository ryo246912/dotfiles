# mise bootstrap トラブルシューティング

`mise bootstrap packages apply`は、宣言した brew パッケージの導入・リンクを mise が管理する仕組み。初回セットアップとは別に、既存環境で発生しうる衝突の対処法をまとめる。

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
   MISE_ENV=mac mise bootstrap packages apply
   ```
5. 別のパッケージで同様のエラーが出た場合は 1〜4 を繰り返す

## real brew から mise bootstrap への本格移行（共有依存の衝突対応）

mise brew も real brew も同じ `/opt/homebrew` prefix を使う。`config.mac.toml` の
`[bootstrap.packages]` に列挙した formula を real brew 側でも個別に入れっぱなしにしていると、
`openssl@3` / `ca-certificates` / `json-c` のような共有依存を real brew が掴んだままになり、
mise 側がリンクできず前述の `cannot link` エラーになる。real brew 中心の環境から mise bootstrap
管理へ本格的に切り替える場合は、以下の手順で real brew 側から該当 formula と共有依存を退避させて
から bootstrap を実行する。

### Phase 1. ブロッカー・移行対象を real brew から抜く

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

### Phase 2. 受け入れテスト

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

# mise bootstrap で user service（定期 push 等）を設定する

`mise bootstrap` は package 導入だけでなく、OS 標準の常駐/定期実行の仕組み（macOS: LaunchAgent、
Linux: systemd user unit）も宣言的に管理できる。`mise.toml` に書いた定義から plist / unit ファイルを
生成し、`launchctl` / `systemctl --user` へ load まで行う。cron を書かずに「N 分ごとに task を叩く」
といった定期ジョブを dotfiles 管理下に置ける。

このリポジトリでは AgentsView のセッションを 15 分ごとに PostgreSQL へ push する定期ジョブに使っている
（[docs/agentsview.md](./agentsview.md) の「定期 push」参照）。以下はその設定を例にした一般的な使い方。

## 定義（mise.toml）

OS 別 config に書く。`[bootstrap.packages]` と同じく、`MISE_ENV` で読み込む config を切り替える。

### macOS（LaunchAgent）

`dot_config/mise/config.mac.toml`:

```toml
[bootstrap.macos.launchd.agents.agentsview-push]
program        = "~/.local/bin/mise"          # launchd の最小 PATH でも辿れるよう絶対パス
args           = ["run", "agentsview:pg:push:daemon"]
run_at_load    = true                          # load 時にも 1 回走らせる
start_interval = 900                           # 秒。15 分ごとに起動
keep_alive     = false                         # 常駐ではなく都度起動なので false
stdout_path    = "~/.local/state/agentsview/push.log"
stderr_path    = "~/.local/state/agentsview/push.log"
```

主なキー: `program` / `args`（実行コマンド）、`run_at_load`（load 時実行）、`start_interval`（秒間隔）、
`start_calendar_interval`（時刻指定）、`keep_alive`（落ちたら再起動する常駐）、`environment`（env 追加）、
`working_directory`、`stdout_path` / `stderr_path`。

### Linux（systemd user timer）

`dot_config/mise/config.linux.toml`:

```toml
[bootstrap.linux.systemd.units.agentsview-push]
description        = "Push AgentsView sessions to PostgreSQL every 15 minutes"
exec_start         = "%h/.local/bin/mise run agentsview:pg:push:daemon"  # %h は systemd が $HOME に展開
type               = "oneshot"
on_boot_sec        = "5min"     # 起動 5 分後に初回
on_unit_active_sec = "15min"    # 以後 15 分ごと
```

timer 系フィールド（`on_unit_active_sec` / `on_boot_sec` / `on_calendar` / `persistent` など）を書くと、
mise が `.service` と `.timer` の両方を生成して timer を有効化する。timer 系を書かなければ常駐 service に
なる（その場合は `restart = "on-failure"` 等を使う）。service 側の主なキー: `description` / `exec_start` /
`type` / `restart` / `restart_sec` / `environment` / `working_directory` / `wanted_by`。

> **`persistent` は monotonic timer には効かない**: `on_boot_sec` / `on_unit_active_sec` は
> monotonic timer で、`persistent`（= `Persistent=`。停止中に逃した分を起動時に補填）は
> `on_calendar`（`OnCalendar=`）のときだけ有効。上記のように 15 分間隔なら次回発火で自然に
> 追いつくため付けていない。停止中の取りこぼしを必ず補填したい場合は、`on_calendar = "*:0/15"` の
> ような calendar timer にしたうえで `persistent = true` を併用する。

## 適用

`chezmoi apply` で config を反映してから、OS 別に bootstrap を適用する。まず `--dry-run` で差分を確認する。

macOS の LaunchAgent は `stdout_path` / `stderr_path` の**ディレクトリが存在しないとログを書けない**
（launchd は program 実行前にログファイルを開き、親ディレクトリは作らない）。ログ出力先を使う場合は
先に作成しておく:

```sh
mkdir -p ~/.local/state/agentsview
```

```sh
# 差分だけ確認（何も触らない）
MISE_ENV=mac   mise bootstrap macos launchd-agents apply --dry-run
MISE_ENV=linux mise bootstrap linux systemd-units apply --dry-run

# 適用（plist/unit を書き出して load / enable）
MISE_ENV=mac   mise bootstrap macos launchd-agents apply
MISE_ENV=linux mise bootstrap linux systemd-units apply
```

Linux の headless / WSL では、ログインしていない間も timer を動かすため lingering を有効化する:

```sh
loginctl enable-linger "$USER"
```

## 状態確認・ログ

```sh
# mise から見た状態（Loaded/Missing/Differs 等）
mise bootstrap macos launchd-agents status      # macOS
mise bootstrap linux systemd-units status        # Linux

# OS 側から
launchctl list | grep agentsview                 # macOS
systemctl --user list-timers 'agentsview-push*'  # Linux（次回発火時刻）
journalctl --user -u agentsview-push -f          # Linux（ログ）
```

## 注意点

- **PATH が最小**: LaunchAgent / systemd user unit は login shell を経ないため PATH が最小
  （`/usr/bin:/bin` 等）。実行コマンドは絶対パス（macOS: `~/.local/bin/mise`、Linux: `%h/.local/bin/mise`）
  で指定する。`mise run <task>` 経由にすれば、その task が使う mise 管理ツール（fnox / flyctl 等）は
  mise が PATH に載せてくれる。
- **secret は env に置かない**: 定期ジョブ用の secret も dotfiles や plist に直書きせず、task 側で
  fnox（bws/age）から解決する。bws の `BWS_ACCESS_TOKEN` は age で解けるため、`~/.config/fnox/age.txt`
  があれば非対話で解決できる（[docs/fnox.md](./fnox.md) 参照）。
- **多重起動対策**: 前回実行が長引いて次の interval と重なりうる場合は、task 側でロック（例: proxy port の
  使用チェック）を入れてスキップさせる。
