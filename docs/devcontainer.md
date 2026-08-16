# devcontainer

AI エージェントを devcontainer 内で実行するための共通基盤に関する設定をまとめます。
devcontainer 定義は `dot_config/devcontainer/` を参照してください。

`multi-worktree` や `crit`（docs/crit.md）など、この base template から起動する
devcontainer はいずれもここに書かれた仕組みを共有します。

## devcontainer 内での docker compose / DB コンテナ（DinD）

base template で `docker-in-docker`（DinD）feature を有効化しているため、devcontainer 内から
`docker` / `docker compose` が使えます。DooD（ホストの `docker.sock` マウント）ではなく DinD を
採用しているので、compose で建てたコンテナ群は dev container 内に隔離され、ホストの docker daemon
には触れません。

**docker データの永続化とコンテナ間の分離**

- docker のイメージ等は named volume `devcontainer-dind-var-lib-docker-${devcontainerId}` に
  永続化され、リビルド時の再 pull を回避します。
- volume 名を `${devcontainerId}` でスコープしているため、multi-worktree で複数の devcontainer を
  同時に起動しても、各コンテナはそれぞれ独立した `/var/lib/docker` を持ちます。共有した場合に起きる
  DinD daemon の起動失敗やメタデータ破損、worktree 間での docker 状態の混入を防ぎます。
- `${devcontainerId}` は同一 devcontainer のリビルドを跨いで安定する識別子のため、分離しつつ
  永続化も維持されます。

## devcontainer からホストへの通知設定（macOS のみ）

devcontainer 内から macOS ホストに通知を送る場合、SSH 経由で通知を行います。
通知経路は「コンテナ → SSH → ホストで `macos-notify-cli` 実行 → 通知センター」で、
コンテナは `host.docker.internal`（SSH config 上の `mac-host`）へ接続し、ホスト上の
`macos-notify-cli` を実行します。初回セットアップ時に以下の設定が必要です：

```bash
# 1. devcontainer 専用の SSH 鍵を生成（既に存在する場合はスキップ）
if [ ! -f ~/.ssh/id_docker_devcontainer ]; then
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_docker_devcontainer
fi

# 2. 公開鍵を authorized_keys に追加（重複チェック付き）
#    ※ 公開鍵は + や / を含むため、grep は必ず -F（固定文字列）で照合する
if ! grep -Fq "$(cat ~/.ssh/id_docker_devcontainer.pub)" ~/.ssh/authorized_keys 2>/dev/null; then
  cat ~/.ssh/id_docker_devcontainer.pub >> ~/.ssh/authorized_keys
fi

# 3. 権限設定（~/.ssh が 700・authorized_keys が 600 でないと sshd は公開鍵を無視する）
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_docker_devcontainer

# 4. リモートログイン（SSH サーバ）を有効化
#    「システム設定 > 一般 > 共有 > リモートログイン」でも可
sudo systemsetup -setremotelogin on
sudo systemsetup -getremotelogin          # → Remote Login: On

# 5. 確認
#    鍵の「中身」で照合すること。ファイル名の docker_devcontainer は鍵のコメント
#    (例: user@host.local) には含まれないため、`grep docker_devcontainer` ではヒットしない
ls -la ~/.ssh/id_docker_devcontainer*
grep -Fq "$(cat ~/.ssh/id_docker_devcontainer.pub)" ~/.ssh/authorized_keys \
  && echo "REGISTERED" || echo "MISSING"
```

## 通知の表示許可（macOS のみ・初回のみ）

SSH 認証が通っても、macOS 側で通知の表示が許可されていないと画面に通知は出ません。
`macos-notify-cli` は表示が抑制されていても `Notification sent successfully` を返すため、
**成功メッセージだけでは表示可否を判断できない**点に注意してください。

- **集中モード / おやすみモード（Focus / Do Not Disturb）を OFF** にする
- **システム設定 > 通知** で `macos-notify-mcp`（`macos-notify-cli` が通知配信に使うアプリ）の
  「通知を許可」を ON にし、スタイルを「バナー」または「通知パネル」にする
- ホスト上で直接 `macos-notify-cli --title test --message hello` を実行し、`Notification sent
successfully` だけでなく**実際にバナーが表示される**ことを確認する

**設定後の動作:**

- コンテナ起動時に自動的に SSH 設定が行われます
- Claude Code の hooks（Notification、Stop）が macOS の通知センターに表示されます
- コンテナを再作成しても設定は永続化されます

**注意事項:**

- macOS の「システム設定 > 一般 > 共有 > リモートログイン」が有効になっている必要があります
- `authorized_keys` へは公開鍵の追加のみで、既存の鍵は保持されます（rename 不要）
- `~/.ssh` は 700、`~/.ssh/authorized_keys` は 600 でないと sshd が公開鍵認証を拒否します

## 通知が届かないときの切り分け

`post-start.sh` などは `BatchMode=yes` / `2>/dev/null` / `|| true` でエラーを握りつぶすため、
どこかで失敗しても静かに無通知になります。各段を手動で確認して原因を切り分けます。

```bash
# ① ホスト自身に鍵で SSH できるか（authorized_keys 登録・権限・リモートログインの確認）
ssh -i ~/.ssh/id_docker_devcontainer -o BatchMode=yes "$USER@localhost" "echo ok"

# ② コンテナ内から mac-host 経由で疎通するか（エラーを握りつぶさずに実行）
ssh -F ~/.config/ssh/config mac-host "echo ok; which macos-notify-cli"

# ③ コンテナ内からホストの通知を直接鳴らせるか
ssh -F ~/.config/ssh/config mac-host \
  "macos-notify-cli --title 'test' --message 'from container' --sound Glass"
```

- ①が失敗 → 公開鍵の未登録 / `~/.ssh` の権限 / リモートログイン無効を疑う
- ①は通るが②の `which` が空 → 非対話 SSH シェルの PATH に mise の shim が無い
- ③まで通るのに画面に出ない → 上記「通知の表示許可」（集中モード・通知許可）を確認

## AIエージェント向けpre-commit

devcontainerでは`AI_AGENT=1`とグローバルな`LEFTHOOK_CONFIG`を設定し、作成時に
Lefthookをインストールする。コミット対象に応じて次の厳格なチェックを実行する。

- Go: `golangci-lint`（govetを含む）、`go test`、`go build`
- Python: `ruff check`、`ruff format --check`
- TypeScript/JavaScript: `oxlint`、`oxfmt --check`、`tsgo --noEmit`

同じチェックは`mise run lint:go`、`mise run lint:python`、
`mise run lint:typescript`で個別にも実行できる。
各言語の集約タスクは`depends`で個別タスクを呼び出す。たとえばGoは
`lint:go:lint`、`lint:go:format`、`lint:go:test`、`lint:go:build`を
必要に応じて単独実行できる。Pythonは`check`と`format`、
TypeScript/JavaScriptは`check`、`format`、`typecheck`に分割している。
自動修正は、言語単位の`mise run fix:go`、`mise run fix:python`、
`mise run fix:typescript`、または配下の個別fixタスクで実行できる。
タスク定義は`~/.config/devcontainer/tasks/`で言語別に管理し、devcontainerの
`/mise/tasks/`へ配置する。
各lint設定はdevcontainerのルートへ標準ファイル名で配置するため、タスク側の
`--config`指定は不要となる。
リポジトリ固有のpre-commit/pre-pushが必要な場合は、
`~/.config/lefthook/lefthook.local.yml`をリポジトリへコピーして編集し、
`LEFTHOOK_CONFIG`をそのファイルへ切り替える。
