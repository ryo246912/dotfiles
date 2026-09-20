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

## devcontainer 内でのコミット署名（SSH 署名）

devcontainer 内で AI エージェント（Claude Code 等）がコミット署名できるようにするための設定です。

ホストの `~/.config/git/config`（`user.signingkey` に個人の GPG 鍵を設定）はコンテナに
読み取り専用でマウントされていますが、GPG の秘密鍵自体（`~/.gnupg`）はマウントしていません。
個人の GPG 秘密鍵をコンテナに置く（＝ AI エージェントの実行環境に晒す）のを避けるため、
devcontainer 専用の SSH 鍵を発行し、[SSH コミット署名](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification)
に切り替えています。ホスト通知用の `id_docker_devcontainer` 鍵とは用途が異なるため、
署名専用の鍵を別に発行して分離しています。

### 初回セットアップ

署名専用の SSH 鍵（`~/.ssh/id_docker_devcontainer_sign`）は `initializeCommand`
（`executable_initialize.sh`、後述）が無ければ自動生成するため、手動での鍵生成は不要です。
`devcontainer up` 実行時にこのコマンドの出力に生成した公開鍵が表示されるので、それを
GitHub に **Signing Key** として登録してください（初回のみ）:

```text
GitHub > Settings > SSH and GPG keys > New SSH key > Key type: Signing Key
```

`dot_config/devcontainer/devcontainer.json` はこの鍵（秘密鍵・公開鍵とも）を
`/home/vscode/.ssh/id_docker_devcontainer_sign(.pub)` に読み取り専用でマウントします。
`postCreateCommand`（`executable_post-create.sh`）が鍵の存在を検知すると、コンテナ内の
`~/.gitconfig` に以下を設定します（include で読み込んだホストの GPG 署名設定より後に
書き込まれるため、後勝ちでこちらが有効になります）:

- `gpg.format = ssh`
- `user.signingkey = ~/.ssh/id_docker_devcontainer_sign`
- `gpg.ssh.allowedSignersFile = ~/.config/git/allowed_signers`
  （`git log --show-signature`等でのローカル検証用。`user.email` と公開鍵から自動生成。
  `namespaces="git"` を付与し、この鍵が git 以外の OpenSSH 署名用途に流用されないよう制限しています）

この鍵（`~/.ssh/id_docker_devcontainer_sign`）は `initializeCommand`（`executable_initialize.sh`）
が存在しない場合に生成する（既存の鍵はそのまま使い、公開鍵だけ都度同期する）ため、通常は常に
mount されており、未セットアップのホストでもコンテナは問題なく起動します。万が一鍵が存在しない
場合（`mounts` からこの鍵を外した構成等）や、鍵が非対話で使えない(パスフレーズ付き等)場合、
`postCreateCommand` は `commit.gpgsign` を明示的に `false` にします。include したホストの
GPG 署名設定（`commit.gpgsign = true` / GPG の `user.signingkey`）をそのままにすると、
GPG 秘密鍵をマウントしていないコンテナでは commit のたびに
`gpg: signing failed: secret key not available` で失敗するためです。

### 動作確認

```bash
git commit --allow-empty -m "test signed commit"
git log --show-signature -1
# Good "git" signature for <email> with ED25519 key SHA256:...
```

GitHub 上でも、push したコミットに `Verified` バッジが付くことを確認してください。

## mounts の source が無いことによるコンテナ作成失敗の防止

devcontainer.json の `mounts` は `docker run --mount` として処理されます。レガシーな `-v`
（bind mount）と違い、`--mount` は host 側の source パスが存在しないと自動生成せず、
`invalid mount config for type "bind": bind source path does not exist` でコンテナ作成自体が
失敗します（target 側はコンテナ内に新規で作られるので問題になりません）。

このリポジトリの `mounts` には、ツール未実行だと存在しないディレクトリ（`~/.config/gh` 等）や、
一度も生成していないと存在しないファイル（devcontainer 専用の SSH 鍵、`~/.claude.json` 等）が
含まれるため、`initializeCommand`（コンテナ作成前にホスト側で実行される devcontainer.json の
フック）で事前に用意しています:

```jsonc
"initializeCommand": "bash '${localEnv:HOME}/.config/devcontainer/scripts/initialize.sh'"
```

`dot_config/devcontainer/scripts/executable_initialize.sh` は各 mount の source を種類ごとに
（ディレクトリは `mkdir -p`、空でよいファイルは `touch`、JSON は `{}`）用意します。ディレクトリや
JSON は既に存在するものには触れませんが、SSH 鍵だけは例外です: 秘密鍵があれば毎回そこから公開鍵を
導出して `.pub` と同期し（欠落時の再構成に加え、秘密鍵だけ手動で差し替えて `.pub` が古いままの
不整合も解消します）、秘密鍵が無いのに孤立した `.pub` だけ残っている場合はそれを削除してから新規に
鍵ペアを生成します。同じ鍵パスを複数の devcontainer（multi-worktree 等）が同時に触る可能性がある
ため、鍵ごとに `mkdir` ロックで生成/同期処理を直列化しています（ロックが取れなくても他プロセスの
完了を無期限には待たず、一定時間で諦めて続行します）。**`mounts` を変更したら、このスクリプトも
合わせて更新してください。**

`~/.config/git/config` や `~/.config/devcontainer/scripts` のように chezmoi apply 済みなら
必ず存在するはずのパスは対象外にしています。ここが無い場合はホスト側のセットアップ自体に
問題があるため、意図的にエラーで気付けるようにしています。

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
