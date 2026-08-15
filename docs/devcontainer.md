# devcontainer

AI エージェントを devcontainer 内で実行するための共通基盤に関する設定をまとめます。
devcontainer 定義は `dot_config/devcontainer/` を参照してください。

`multi-worktree` や `crit`（docs/crit.md）など、この base template から起動する
devcontainer はいずれもここに書かれた仕組みを共有します。

## aws-vault の認証を container 内の AI agent で使う

macOS host の Keychain を container へ mount するのではなく、host の `aws-vault exec` が発行した
短期 credential を devcontainer の起動時に渡します。これにより container 内の AWS CLI、SDK、mcpc
経由の AWS MCP を同じ AWS account と role で利用できます。

### 初回セットアップ

host で mcpc 用 MCP config を生成します。この config に credential は含まれません。

```bash
chezmoi apply
mise run apm:install
test -f ~/.config/mcpc/apm-home/.copilot/mcp-config.json
```

次に、利用する aws-vault profile の子 process として devcontainer を起動します。

```bash
aws-vault exec my-profile -- \
  devc-up-wrapper devcontainer up \
  --workspace-folder . \
  --config "$HOME/.config/devcontainer/devcontainer.json" \
  --remove-existing-container
```

`aws-vault exec` が設定する `AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`AWS_SESSION_TOKEN`、region、
expiration、`AWS_VAULT` を `remoteEnv` が container へ転送します。profile 名を独自の環境変数で管理する
必要はありません。

起動後は container 内で認証先を確認します。秘密値そのものは表示しないでください。

```bash
aws sts get-caller-identity
printf 'profile=%s expires=%s\n' "$AWS_VAULT" "$AWS_CREDENTIAL_EXPIRATION"
```

AI agent も同じ環境を継承するため、container 内では plain `mcpc` で接続できます。

```bash
mcpc connect ~/.config/mcpc/apm-home/.copilot/mcp-config.json:aws-cloudwatch @aws-cloudwatch
mcpc @aws-cloudwatch tools-list
```

### account・role の切り替えと credential の更新

credential は container 起動時点のものです。別 profile への切り替えや期限切れ後の更新では、既存の mcpc
session を閉じ、devcontainer を停止して、新しい profile の `aws-vault exec` 配下から再度起動します。

```bash
# container内
mcpc close @aws-cloudwatch
exit

# host（既存containerを削除して新しいcredentialで作り直す）
aws-vault exec another-profile -- \
  devc-up-wrapper devcontainer up \
  --workspace-folder . \
  --config "$HOME/.config/devcontainer/devcontainer.json" \
  --remove-existing-container
```

使用中の devcontainer へ後から `aws-vault exec` だけを実行しても、既存 process の環境は更新されません。
account/role を混同しないため、credential 更新時は container の再起動と MCP session の再接続をセットで
行います。

### セキュリティ上の注意

- container 内の process と AI agent は一時 credential を読めます。信頼できる repository と MCP server
  だけを起動し、AWS側では最小権限の roleを使用してください。
- `env`、debug log、agent の会話へ秘密値を出力しないでください。確認には
  `aws sts get-caller-identity` と `AWS_CREDENTIAL_EXPIRATION` を使います。
- credential は dotfiles、APM manifest、MCP config には書き込まれませんが、container runtime の環境として
  保持されます。共有hostでは Docker inspect 権限を持つ利用者も秘密値を参照できる前提で運用してください。
- 長時間稼働させず、作業終了後は container と mcpc session を停止してください。

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
