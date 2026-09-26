# devcontainer

AI エージェントを devcontainer 内で実行するための共通基盤に関する設定をまとめます。
devcontainer 定義は `dot_config/devcontainer/` を参照してください。

`multi-worktree` や `crit`（docs/crit.md）など、この base template から起動する
devcontainer はいずれもここに書かれた仕組みを共有します。

## devcontainer からホスト側 tmux pane を読む

ホスト側の開発サーバーログを、devcontainer 内の AI エージェントから確認する場合は
`host-tmux` を使います。コンテナへ bind mount される devcontainer scripts に同コマンドを置き、
既存の `mac-host` SSH 接続上でホストの tmux client を実行します。tmux socket 自体をコンテナへ
mount しないため、ホストとコンテナの UID や socket path の差に依存しません。

```bash
# pane ID（%3 など）、実行中コマンド、作業ディレクトリを一覧表示
host-tmux list

# 指定した pane の直近 200 行を取得（行数は省略可能、既定値は 200）
host-tmux capture %3 200
```

AI エージェントには `/tmux %3`（Codex では `$tmux %3`）と指示すると、追加した tmux skill が
`host-tmux capture` を呼び出してログを分析します。継続的なログ監視が
必要なら、同じ capture コマンドを一定間隔で再実行させます。pane ID は tmux の session/window 構成を
変えると変わり得るため、固定値を設定へ埋め込まず、その都度 `list` で確認してください。

この経路は読み取り専用のラッパーですが、利用する SSH 鍵自体は通常のホストログイン権限を持ちます。
鍵をより厳密に制限したい場合は、ホスト側 `authorized_keys` の `command=` で許可コマンドを制限する
専用鍵・専用 dispatcher を別途用意してください。また、後述のリモートログイン、公開鍵登録、
`mac-host` 設定が完了している必要があります。

## ホストと共有しないプロジェクト生成物

ワークスペース自体はホストから bind mount しますが、次のディレクトリは起動時に検出し、コンテナの
writable layer (`/var/lib/devcontainer-project-artifacts`) を bind mount してホスト側の内容を隠します。
macOS ホストと Linux コンテナでネイティブバイナリや実行環境を共有することによる衝突を防ぎます。

- `node_modules`: Node.js の依存パッケージ
- `.venv`: Python 仮想環境
- `target`: Rust / Maven などのビルド成果物
- `.gradle`: Gradle のプロジェクトキャッシュ
- `.terraform`: Terraform provider の実行ファイルと初期化データ

### writable layer と bind mount を使う理由

通常、`${localWorkspaceFolder}/node_modules` はワークスペースの bind mount に含まれるため、コンテナから
書いた内容がそのまま macOS 側にも現れます。この設定では、同じパスへコンテナ内の別ディレクトリを
bind mount して、次のように見える場所と実際の保存先を差し替えます。

| コンテナから見えるパス              | 実際の保存先（コンテナ内）                       | ホストから見える内容          |
| ----------------------------------- | ------------------------------------------------ | ----------------------------- |
| `<workspace>/apps/web/node_modules` | `/var/lib/devcontainer-project-artifacts/<hash>` | mount point用の空ディレクトリ |
| `<workspace>/packages/api/.venv`    | `/var/lib/devcontainer-project-artifacts/<hash>` | mount point用の空ディレクトリ |

Dockerコンテナのwritable layerは、そのコンテナだけが持つ書き込み領域です。ここを保存先にすることで、

- Linux用native addonや実行ファイルがmacOS側へ書き込まれない
- ホストに既にあるmacOS用生成物はmountの下に隠れ、コンテナから誤って利用されない
- 別のdevcontainerとも生成物を共有しない
- named volumeと違い、コンテナ削除時にDockerがwritable layerも削除するため手動掃除が不要

という状態になります。ソースコードなど他のファイルは従来のworkspace bind mount上にあるため、コンテナでの
編集は引き続きホストへ反映されます。生成物ディレクトリだけを局所的に差し替えるのがこの方式のポイントです。

ワークスペース直下だけでなく、既存の対象ディレクトリを任意の深さから検出します。また、まだ対象が
作られていなくても `package.json`、`pyproject.toml`、`Cargo.toml`、`pom.xml`、Gradle 設定、Terraform
ファイルなどの場所から mount point を作るため、monorepo の `apps/*` や `packages/*` も分離されます。
`.git` と検出済みの生成物以下は走査しません。

`target` は一般的なディレクトリ名でもあるため、名前だけでは検出しません。同じ階層に`Cargo.toml`または
`pom.xml`がある場合に限り、Rust/Mavenの生成物として分離します。

格納先は Docker named volume ではなくコンテナ自身の writable layer です。ホストや別のコンテナとは共有されず、
コンテナを削除すれば生成物も一緒に削除されるため、volume の手動削除は不要です。コンテナの停止・再起動時には
`postStartCommand` が bind mount を張り直すので、同じコンテナ内の生成物は引き続き利用できます。

bind mountのtargetにはLinuxの仕様上ディレクトリが必要です。対象が未作成の場合はworkspace（ホスト）側にも
空のmount pointが作られますが、依存パッケージやビルド成果物の実体はそこへ書かれません。この空ディレクトリは
通常それぞれのツール向け`.gitignore`の対象です。

検出は`postCreateCommand` / `postStartCommand`を実行した時点のスナップショットです。manifestのない場所で
起動中に`python -m venv .venv`などを新規実行すると、その回はホスト側へ作成されます。また、後からスクリプトを
実行しても既存内容はコンテナ側へコピーせず、mountの下に隠します。これはmacOS用生成物をLinux環境へコピーして
再利用しないための意図的な動作です。その場合はホスト側の生成物を削除し、下記コマンドでmountした後にコンテナ内で
依存関係を作り直してください。

プロジェクト定義ファイルを追加した直後など、コンテナ起動後に新しい対象パスが生じた場合は、次を実行するか
コンテナを再起動してください。

```bash
bash ~/.config/devcontainer/scripts/mount-container-only-dirs.sh "$PWD"
```

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

### commit が `Author identity unknown` で失敗する場合

コンテナ内の `~/.gitconfig` は `postCreateCommand`（`executable_post-create.sh`）が作ります。ホストの
`user.name` / `user.email` は `~/.config/gitconfig-host` として読み取り専用でマウントされていますが、
`~/.gitconfig` の `include.path` から参照しない限り git には読まれません。そのため
`post-create.sh` が `~/.gitconfig` を作る前に止まると、`gitconfig-host` があっても identity は未設定のままです。

`post-create.sh` は `set -e` のため、以前は git の設定より前にある処理（プロジェクト生成物の分離・
Lefthook のインストール）が失敗すると、identity の設定まで到達しませんでした。現在は次の順序にしています。

1. git の `include.path` / 認証 / コミット署名の設定（identity の解決を確認し、解決できなければ警告）
2. プロジェクト生成物の分離（失敗したら止める。分離できないまま依存インストール等が走ると、
   生成物がホスト共有のワークスペースへ書き込まれるため。identity の設定処理は 1 で実行済み）
3. Lefthook のインストール（失敗しても警告して続行）
4. `.claude.json` のコピー、`claude-account2` の共有、`~/.crit.config.json` の生成

`Author identity unknown` が出た場合は、次で切り分けます。

```bash
ls -la ~/.gitconfig ~/.config/gitconfig-host   # ~/.gitconfig が無ければ post-create.sh が未完了
git config --global --get-all include.path     # gitconfig-host が含まれているか
git config user.name && git config user.email  # 空ならホスト側の ~/.config/git/config の [user] を確認
bash ~/.config/devcontainer/scripts/post-create.sh  # 冪等なので再実行して復旧できる
```

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
ため、鍵ごとに生成/同期処理を直列化しています。`flock` があればそれを使う（プロセスの fd に
紐づく OS レベルのロックで、TOCTOU が原理的に無く、プロセスが死ねば OS が自動的に解放するため
孤児ロックも発生しない。WSL2/Linux では標準で入っていることが多い）。`flock` が無い環境向けには
`mkdir` ベースのフォールバックを用意している（ロックが取れなくても他プロセスの完了を無期限には
待たず一定時間で諦める、死んだ/孤児ロックをベストエフォートで回収する、というだけで `flock` ほど
厳密ではない）。**`mounts` を変更したら、このスクリプトも合わせて更新してください。**

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

## AIエージェント向けpre-commit

devcontainerでは`AI_AGENT`を設定し、作成時にAIエージェント向けの
Lefthook pre-commitをインストールする。ジョブは`AI_AGENT`が空でない場合に実行するため、
エージェント側が`claude-code_2-1-218_agent`のような識別子で値を上書きしても動作する。

pre-commitでは、未stageの変更と未追跡ファイルを一時的にstashし、stage済みの内容だけを
worktreeに残してlintする。lintの成否にかかわらず最後のジョブでstashを復元する。

- stashの対象から、`mount-container-only-dirs.sh`がbind mountする`node_modules` / `.venv` / `.gradle` /
  `.terraform` / `target`を配下のファイルごと（`**/node_modules/**`など）除外する。`.gitignore`対象でないと、
  これらは未追跡の空ディレクトリとして`git stash -u`の削除対象になり、`Device or resource busy`で
  失敗するため。ディレクトリ名だけの除外では、mount内の生成物がstashに取り込まれる。stashが途中で失敗しても
  復元用のマーカーを書いてから失敗を返すので、後続の`stash pop`で未追跡ファイルは復元される。
- `shell`ジョブは`mise run lint:shell`を実行し、対象はgit管理下の`*.sh`だけにしている
  （`shfmt -l $(git ls-files '*.sh')`）。`shfmt -l .`は`.zsh`なども探索し、bashとして解析できず
  失敗するため。shfmtには「解析できるものだけを対象にする」オプションが無いので、拡張子で絞っている。
  整形差分があるファイルが1つでもあると（`shfmt -l`は終了コード1を返す）、`*.sh`を含むコミットは
  リポジトリ内の既存ファイルの差分でも失敗する。
- `lefthook.local.yml`は各リポジトリに無い場合だけテンプレートからコピーされる。既に配置済みの
  リポジトリへテンプレートの変更を反映するには、`~/.config/devcontainer/lefthook.local.yml`を
  そのリポジトリの`lefthook.local.yml`へ上書きコピーする。

multi-worktreeのようにworkspace直下に複数のリポジトリ（`repo-a/`、`repo-b/`など）を並べる構成では、
`multi-worktree-*`ブランチのtask rootだけを複数リポジトリ構成として扱い、直下で`.git`を持つ
各リポジトリへ`lefthook.local.yml`を配置して、それぞれに`lefthook install`する。
通常のworkspaceは直下にsubmoduleがあっても、workspaceが属する親リポジトリへインストールする。

フックはホストと共有する`.git/hooks`へ書き込まれるため、コンテナを破棄した後も残る。
非AI環境ではAI向けジョブはスキップされるが、ホストにLefthookがない場合はcommitが
失敗する。不要になったフックは、対象リポジトリのdevcontainer内で
`lefthook uninstall`を実行して削除する。
