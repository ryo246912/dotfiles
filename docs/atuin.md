# atuin

[atuin](https://github.com/atuinsh/atuin) はシェル履歴を SQLite に保存し、暗号化したうえで複数マシン間で同期するツールです。
この dotfiles では、自前の同期サーバー（Fly.io の `ryo-shellhistory`）に履歴を集約しています。

## 構成

| 項目               | 場所 / 値                                                                  |
| ------------------ | -------------------------------------------------------------------------- |
| CLI のバージョン   | `config/mise/config.toml` の `aqua:atuinsh/atuin`                          |
| クライアント設定   | `config/atuin/config.toml`（`~/.config/atuin/config.toml` に配置）         |
| シェル統合         | `config/zsh/lazy/mise.zsh`（`atuin init zsh` と補完の生成）                |
| スニペット         | `config/zabrze/general.toml`（`ats` / `ase` / `atst`）                     |
| 同期サーバー       | `https://ryo-shellhistory.fly.dev`（`config/atuin/fly.toml`）              |
| サーバーの DB      | Fly PostgreSQL（`psgl`、private network の `psgl.flycast` 経由）           |
| サーバーのデプロイ | `.github/workflows/deploy-atuin.yaml`（main の `fly.toml` 変更で自動実行） |

CLI とサーバーイメージ（`ghcr.io/atuinsh/atuin`）は Renovate の `atuin` グループで同時に更新されます。

### シェル統合で無効にしているもの

`atuin init zsh --disable-up-arrow --disable-ctrl-r --disable-ai` で初期化しているため、atuin はキーを奪いません。

- <kbd>↑</kbd> / <kbd>Ctrl</kbd>+<kbd>R</kbd> は zsh 標準・他ツールのまま
- <kbd>?</kbd>（18.13.0 以降の既定では空プロンプトで Atuin AI が起動する）も無効

履歴の記録（preexec / precmd フック）だけが有効で、検索は下記のスニペットから呼び出します。

### daemon

`[daemon] enabled = true` / `autostart = true` により、コマンド記録時に daemon が必要に応じて自動起動します
（`atuin daemon start --daemonize`）。daemon は `sync_frequency`（300 秒）ごとにサーバーと同期するので、
コマンドをあまり実行しなくても履歴が他マシンに反映されます。

## 日常の使い方

### 履歴を検索する

| 入力（zabrze） | 展開後            | 用途                       |
| -------------- | ----------------- | -------------------------- |
| `ats` / `ase`  | `atuin search -i` | インタラクティブ検索 (TUI) |
| `atst`         | `atuin stats`     | よく使うコマンドの統計     |

TUI の主なキー操作:

| キー                                          | 動作                                                            |
| --------------------------------------------- | --------------------------------------------------------------- |
| <kbd>Enter</kbd>                              | 選択したコマンドを実行                                          |
| <kbd>Tab</kbd>                                | 選択したコマンドをプロンプトに挿入して編集                      |
| <kbd>Ctrl</kbd>+<kbd>R</kbd>                  | filter mode を切り替え（global / host / session / directory …） |
| <kbd>Ctrl</kbd>+<kbd>S</kbd>                  | search mode を切り替え（fuzzy / prefix / fulltext …）           |
| <kbd>Alt</kbd>+<kbd>1</kbd>〜<kbd>9</kbd>     | 番号で選択                                                      |
| <kbd>Ctrl</kbd>+<kbd>O</kbd>                  | inspector（実行時刻・所要時間・終了コードなどの詳細）を開く     |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd>                  | 選択したコマンドをクリップボードにコピー                        |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> → <kbd>d</kbd>   | 選択した履歴を削除                                              |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> → <kbd>D</kbd>   | 選択したコマンドと一致する履歴をすべて削除                      |
| <kbd>Esc</kbd> / <kbd>Ctrl</kbd>+<kbd>C</kbd> | 何もせず終了                                                    |

`search_mode = "fuzzy"`、`style = "compact"`、`show_preview = true` が既定です（`config/atuin/config.toml`）。

### 条件を付けて検索する（非インタラクティブ）

```sh
# 今いるディレクトリで実行した、失敗した docker コマンド
atuin search --cwd . --exit 1 docker

# 期間を指定して、コマンドだけを出力
atuin search --after "2026-10-01" --before "yesterday" --cmd-only git

# 成功したコマンドだけ、新しい順に 20 件
atuin search --exclude-exit 1 --limit 20 --reverse kubectl
```

### 履歴を一覧・統計表示する

```sh
atuin history list --format "{time}\t{duration}\t{command}"  # 一覧
atuin history last                                           # 直前のコマンド
atuin stats                                                  # よく使うコマンド上位 10 件
atuin stats -c 20 -n 2                                       # 上位 20 件、2 コマンドの並びで集計
```

`common_subcommands` に入っている `git` / `npm` / `gh` / `docker` / `docker-compose` / `make` は、
統計でサブコマンドまで区別して集計されます。

### 履歴を削除する

```sh
# 一致する履歴を確認してから削除する（--delete は表示された全件を消す）
atuin search --cwd . "secret"
atuin search --cwd . "secret" --delete

# 設定済みの除外フィルタに一致する履歴を削除
atuin history prune

# 同じコマンド・cwd・ホストの重複を削除
atuin history dedup
```

削除はサーバー経由で他マシンにも同期されます。

## 同期

```sh
atuin status          # ログイン状態と最終同期時刻
atuin sync            # 手動で同期
atuin daemon status   # daemon のバージョンと稼働状態
atuin doctor          # 設定・シェル統合・daemon の診断
```

### 新しいマシンでのセットアップ

[setup.md](setup.md) の atuin の手順と同じです。

1. `mise install` で atuin を入れ、シェルを開き直す
2. 既存マシンで `atuin key` を実行して暗号鍵を表示する
3. 新しいマシンで `atuin login` を実行し、ユーザー名・パスワード・鍵を入力する
4. `atuin sync` で履歴を取得する
5. 必要なら、atuin の履歴を zsh の履歴ファイルにも反映する（setup.md 参照）

サーバーは `ATUIN_OPEN_REGISTRATION=false` なので、`atuin register` で新しいアカウントは作れません。

## サーバー（Fly.io）

- `config/atuin/fly.toml` を変更して main にマージすると、`deploy-atuin` ワークフローが `flyctl deploy` を実行します
- 手動デプロイは `flyctl deploy --app ryo-shellhistory -c config/atuin/fly.toml`（navi の `fly` チートにもあります）
- ログは `flyctl logs -a ryo-shellhistory`、DB への接続は `flyctl postgres connect -a psgl`
- マシンはリクエストがないと停止し（`auto_stop_machines = "stop"`）、アクセスで起動します
- v18.12.0 以降、イメージの ENTRYPOINT は `atuin-server` です。`fly.toml` の `cmd` は `["start"]` を指定します
  （`["server", "start"]` は 18.11 以前の形式）

DB を CockroachDB などへ移さない理由は [fly.md](fly.md) を参照してください。

## アップグレード時の注意

Renovate の `atuin` グループ PR をマージするときは次を確認します。

- **サーバーのマイグレーション**: 新しいサーバーは起動時に PostgreSQL のマイグレーションを自動実行し、元に戻せません。
  大きなバージョン差があるときは事前に DB のバックアップを取ります
- **クライアントをまとめて更新する**: 18.13.0 で履歴レコードの形式が v1 になりました。古いクライアントが残っていると、
  同期したレコードを読めないことがあります。全マシンを同じタイミングで更新します
- **daemon を再起動する**: 更新後は古い daemon が残っているので、各マシンで一度止めてからシェルを開き直します

  ```sh
  atuin daemon stop || pkill -f "atuin daemon"
  ```

- **`atuin init` の既定値の変化**: 新しいキー割り当て（Atuin AI など）が既定で有効になることがあります。
  `atuin init zsh --help` で `--disable-*` フラグを確認し、必要なら `config/zsh/lazy/mise.zsh` に追加します
- **リリースノート**: サーバーの起動コマンドや設定キーの変更は upstream の
  [CHANGELOG](https://github.com/atuinsh/atuin/blob/main/CHANGELOG.md) で確認します

## トラブルシューティング

| 症状                                               | 対処                                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `Failed to find $ATUIN_SESSION in the environment` | `atuin init zsh` が読み込まれていない。シェルを開き直すか、`mise.zsh` の読み込みを確認する  |
| 他マシンの履歴が反映されない                       | `atuin status` で最終同期を確認し、`atuin sync` を実行。`atuin daemon status` も確認する    |
| 鍵が違うというエラー（wrong key）                  | `atuin key` の値が他マシンと一致しているか確認し、`atuin logout` → `atuin login` でやり直す |
| 復号できないレコードがあるというエラー             | `atuin store verify` で確認し、不要なら `atuin store purge` で削除する                      |
| daemon が古いバージョンのまま                      | `atuin daemon stop` してからシェルを開き直す（autostart で新しいバージョンが起動する）      |
