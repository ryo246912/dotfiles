# devcontainer

AI エージェントを devcontainer 内で実行するための共通基盤に関する設定をまとめます。
devcontainer 定義は `config/devcontainer/` を参照してください。

`multi-worktree` や `crit`（docs/crit.md）など、この base template から起動する
devcontainer はいずれもここに書かれた仕組みを共有します。

> [!NOTE]
> AI エージェントの実行環境は **Docker Sandboxes (`sbx`) を既定**に切り替えています。
> `multi-worktree dev <task>` は sandbox を起動し、devcontainer は `--devcontainer` を
> 付けたときのフォールバック経路です。移行の背景と sandbox 側の使い方は
> [docs/docker-sandboxes.md](./docker-sandboxes.md) を参照してください。
>
> このページのツールチェイン（`mise.toml` / `tasks/` / `lint/`）とホスト連携スクリプト
> （通知・crit・plannotator・host-tmux・lefthook）は **`Dockerfile.sandbox` 経由で sandbox 側にも
> 移植済み**で、同じファイルを共有しています。これらは bind mount ではなく image へ COPY して
> いるため、`mise.toml` / `tasks/` / `lint/` / `scripts/` / `lefthook.local.yml` のいずれかを
> 変更したら `mise run sandbox:build-template` で sandbox 用 template を作り直してください。
> 項目ごとの再現状況と、まだ差分が残っている点（生成物ディレクトリの分離など）は
> [devcontainer との機能対応表](./docker-sandboxes.md#devcontainer-との機能対応表) にまとめています。

## workspace と Git metadata の mount 範囲

リポジトリ関連でコンテナに mount するのは workspace と、その git が参照する common git dir（実体リポジトリの
`.git`）だけです。`~/project/repo` のような通常 checkout で `../..` を mount すると
`$HOME` 全体がコンテナから見えるため、親ディレクトリは mount しません。

linked worktree の `.git` file と、common git dir 側の `worktrees/<name>/gitdir` は
どちらも絶対パスです。そこで workspace と common git dir を**ホストと同じ絶対パス**に
mount し、ホスト・コンテナのどちらでも同じパスで git が解決できるようにしています。
relative-paths 形式（`git worktree add --relative-paths` / `worktree.useRelativePaths`）は使いません。
相対パスはホストとコンテナで mount 先のパスが違うと参照先がずれます。また repo に
`extensions.relativeWorktrees` が付き、git 2.48 未満（コンテナの Ubuntu 24.04 の git 2.43 など）が
その repo を読めなくなります。

### コンテナ内の注意点

- 同じリポジトリの他の worktree はコンテナから見えません。post-create で
  `gc.worktreePruneExpire = never` を設定し、`git gc` の自動 prune がそれらの
  `.git/worktrees/<name>` を削除しないようにしています。コンテナ内で
  `git worktree prune` を手動実行しないでください。ホスト側の worktree が壊れます。
- 既存のコンテナは `devcontainer up` しても mount が更新されません。config を変えたら
  `multi-worktree recreate <task>` で再生成し、コンテナを作り直してください
  （`devcontainer up ... --remove-existing-container`）。

### relative-paths 形式の worktree を戻す

relative-paths 形式で作った worktree が残っていると、コンテナ内で git が使えません。
ホストの git 2.48 以上で、実体リポジトリごとに次を実行して絶対パス形式に戻してください。

```bash
cd ~/path/to/repo
git config --global --unset worktree.useRelativePaths   # 設定している場合
# 引数なしの repair は main worktree しか直さないため、各 worktree のパスを渡す。
# 全件成功したときだけ extension を外す（zsh で exit がシェルを閉じないよう subshell で実行）
(
  git worktree list --porcelain | sed -n 's/^worktree //p' |
    while IFS= read -r wt; do git worktree repair --no-relative-paths "$wt" || exit 1; done
) && git config --unset extensions.relativeWorktrees
```

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

## イメージのリビルド高速化（mise ツールのキャッシュ）

`config/devcontainer/mise.toml` を変更すると `mise install` の layer は必ず再実行されますが、
全ツールをゼロから入れ直さないよう `Dockerfile` で次の工夫をしています。

- インストール済みツール（`/mise/data`）を BuildKit の cache mount（id: `devcontainer-mise-data`）に
  保存し、次回ビルド時に rsync で復元してから `mise install` します。バージョンが変わったツールだけが
  ダウンロード/ビルドされます。
- install 先は常に `/mise/data` のままなので、shim や shebang の絶対パスは壊れません。
- 復元した古いバージョンは `mise prune --tools` で削除を試みます（失敗時は警告のみでビルドを続行するため、残る場合があります）。
- go（`GOMODCACHE` / `GOCACHE`）と bun のキャッシュも cache mount（id: `devcontainer-mise-cache`）に置いて再利用します。
- `tasks/` の COPY は install の後に置き、tasks の変更で install layer が無効化されないようにしています。

cache mount は `docker builder prune` で削除されます（削除されても初回と同じフルインストールになるだけです）。

## このディレクトリの共有範囲（devcontainer / sandbox）

`config/devcontainer/` は devcontainer と Docker Sandboxes の両方から使われます。

| ファイル                                   | devcontainer               | Docker Sandboxes                                         |
| ------------------------------------------ | -------------------------- | -------------------------------------------------------- |
| `devcontainer.json`                        | 本体の定義                 | 未使用                                                   |
| `Dockerfile`                               | devcontainer の image      | 未使用                                                   |
| `Dockerfile.sandbox`                       | 未使用                     | `mise run sandbox:build-template` が使う template の定義 |
| `mise.toml` / `tasks/` / `lint/`           | bind mount + image に COPY | image に COPY（同じ内容）                                |
| `scripts/`                                 | bind mount                 | image に COPY                                            |
| `lefthook.local.yml`                       | bind mount                 | image に COPY                                            |
| `scripts/initialize.sh`                    | `initializeCommand`        | `mise run sandbox:setup` が流用                          |
| `scripts/post-create.sh` / `post-start.sh` | `postCreateCommand` 等     | 未使用（代わりに `sandbox-post-create.sh`）              |
| `scripts/sandbox-post-create.sh`           | 未使用                     | `sbx exec` で sandbox 作成直後に実行                     |

## symlink で配置されたホスト設定の扱い

mise の `[dotfiles]` は `~/.config` / `~/.claude` / `~/.codex` を **`symlink-each`** で配置します
（`mise.toml` の `[dotfiles."~/.config"]` を参照）。
`~/.config/devcontainer/mise.toml` や `~/.config/nvim/init.lua` は実ファイルではなく、
**dotfiles リポジトリを指す symlink** です。これが devcontainer に 2 つの影響を与えます。

### 1. build context に使えない

BuildKit は **build context の外を指す symlink を辿りません**。
`~/.config/devcontainer` をそのまま context にすると、`Dockerfile` の

```dockerfile
COPY --chown=vscode:vscode mise.toml /mise/config.toml
```

が `failed to compute cache key: "/mise.toml": not found` で失敗します
（`COPY . ...` のようなディレクトリ単位の COPY は「成功するがリンク切れが入る」ため、
より分かりにくい壊れ方をします）。

そこで `initializeCommand`（`scripts/initialize.sh`）が、symlink を解決した実体のコピーを
`~/.cache/devcontainer/host-config/` に作り、`devcontainer.json` はそちらを
`build.context` / `build.dockerfile` に指定しています。

```jsonc
"context": "${localEnv:HOME}/.cache/devcontainer/host-config/devcontainer",
"dockerfile": "${localEnv:HOME}/.cache/devcontainer/host-config/devcontainer/Dockerfile",
```

`initializeCommand` はコンテナ作成前に毎回ホスト側で走るため、`~/.config` 側の編集は
次の起動でコピーに反映されます。反映は**差分のみ**（更新は上書き、`~/.config` 側から
消えた entry だけ削除）で、ディレクトリごと作り直すことはしません。
`~/.config/<name>` がディレクトリごと消えた場合は、コピーの中身を空にして
ディレクトリ自体は残します（mount 元として要るため）。残しておくと「消したはずの設定」が
新しいコンテナへ mount され続けるからです。元から無いもの（未導入のツール等）は
何もせず成功扱いにするので、毎回 warning が出ることはありません。
このコピーは起動中の devcontainer が bind mount しているため
（`multi-worktree` では複数が同時に動く）、作り直すと動いているコンテナから
設定が消えてしまいます。コピー後に `Dockerfile` / `mise.toml` / `tasks` / `lint` /
`scripts` / `lefthook.local.yml` が揃っているかを検証し、欠けていればそこで止めます
（dotfiles 未適用やリンク切れを、分かりにくい `docker build` エラーの前に検出するため）。

> [!NOTE]
> 置き場所を `XDG_CACHE_HOME` ではなく `~/.cache` 固定にしているのは、
> `devcontainer.json` の `${localEnv:...}` に既定値を書けないためです
> （未設定の環境変数は空文字になり、mount の source が壊れます）。

### 2. ディレクトリ単位の bind mount でリンク切れになる

`~/.config/nvim` のようにディレクトリごと mount すると、中身の symlink はそのまま
コンテナ内へ渡り、リンク先（ホストのリポジトリのパス）がコンテナ内に無いため
**リンク切れ**になります。対処は mount の性質によって分けています。

| mount                                                                                                                       | 対処                                                                                   |
| --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `~/.config/devcontainer` / `nvim` / `mise`（ディレクトリ・readonly）                                                        | 実体化したツリー（`~/.cache/devcontainer/host-config/<name>`）を source にする         |
| `~/.config/git/config` / `gitignore` / `~/.claude.json` / `~/.claude/settings.json` / `~/.codex/config.toml` / `hooks.json` | 実体化したファイル（`~/.cache/devcontainer/host-config/files/<name>`）を source にする |
| `~/.config/gh` / `~/.agents` / `~/.copilot` など                                                                            | dotfiles 管理外（実ファイル）なので対処不要                                            |

> [!IMPORTANT]
> **ファイル単位の mount でも Docker の symlink 解決に頼ってはいけません。**
> 当初は「ファイル単位なら Docker が source 側の symlink を解決するので対処不要」と
> 考えていましたが、実際には symlink がコンテナ内へそのまま渡り、
> `core.excludesfile` が指す `/home/vscode/.config/gitignore-host` が
> `fatal: ... Too many levels of symbolic links` で読めなくなる事例が出ました。
> こうなると `git status` / `git diff` 系が全滅し、それを内部で呼ぶ crit なども落ちます
> （`git -c core.excludesFile= status` だけ通ることで切り分けできます）。
> そのため**ディレクトリもファイルも区別せず、すべて実体化したコピーを渡しています**。

`~/.claude` / `~/.codex` はディレクトリごと read-write で mount（エージェントが
`projects/` などを書き戻すため）したうえで、その上に dotfiles 管理のファイルだけを
実体化したコピーから readonly で重ねています。read-write の mount 自体はコピーにできない
（書き戻しが repo に反映されない）ため、この 2 層構成になっています。

`git/config` と `git/gitignore` はコンテナ内の git が常に読むため、実体化に失敗したら
**コンテナ作成を止めます**。他のファイルは warning 止まりですが、`mounts` の source が
無いとコンテナ作成自体が失敗するため、失敗時は空の実体を置いて mount 元を確保します。

### `include.path` は特別扱いが必要（読めないと git が即死する）

`post-create.sh` はホストの gitconfig を `include.path` で取り込みます。

```bash
git config --global --add include.path ~/.config/gitconfig-host
```

ここで重要なのは、**`include.path` が読めないときの git の挙動が `core.excludesfile` と違う**ことです。

| 設定                | 指す先が読めないとき                  |
| ------------------- | ------------------------------------- |
| `core.excludesfile` | `warning:` が出るだけ（終了コード 0） |
| `include.path`      | **`fatal:` で即死（終了コード 128）** |

```console
$ git status                      # include.path が symlink ループを指している場合
fatal: unable to access '.../gitconfig-host': Too many levels of symbolic links
```

`status` / `diff` に限らず**あらゆる git コマンド**が落ちるため、git を内部で呼ぶツール
（crit など）もまとめて動かなくなります。

さらに厄介なのが、**git は自分で壊れた `include.path` を外せない**点です。
`git config --get-all` も `--unset-all` も include を展開しようとして同じ `fatal` で
落ちるため、`git config` 経由では修復できません。

```console
$ git config --global --unset-all --fixed-value include.path .../gitconfig-host
fatal: unable to access '.../gitconfig-host': Too many levels of symbolic links
# → ファイルは変更されない
```

そのため `post-create.sh` は次の 3 段構えにしています。

1. 登録前に `[ -r "$gitconfig_host" ]` で読めることを確認する（読めなければ登録しない）
2. 前回の実行で登録済みの壊れた `include.path` は、`~/.gitconfig` を
   **awk で直接書き換えて**取り除く（git では外せないため）。他の `include.path` は残す。
   置換時は元のモードを `stat -Lc` で引き継ぎ（`-L` なしだと symlink 自身の 777 を拾う）、
   `mv` の宛先は `readlink -f` で実体にする（`~/.gitconfig` が symlink の場合にリンクを壊さない）
3. そのうえで **`exit 1` で失敗させる**。続行するとホストの `user.name` / `user.email` が
   無いまま成功扱いになり、後の commit で `Author identity unknown` として表面化するため

つまり「一度壊れたらコンテナ内の git が一切使えない」状態には陥らず（壊れた include は
取り除かれるので調査中も git は使える）、かつ**壊れていること自体は `devcontainer up` の
失敗として見える**ようにしています。この状態になったらホスト側で
`mise bootstrap dotfiles apply` を実行し、devcontainer を作り直してください。

> [!NOTE]
> `initialize.sh` が成功していても、ここで失敗しうることに注意してください。
> `initialize.sh` が検証しているのは**ホスト側の実体化コピー**であって、
> コンテナ内の mount が読めることは保証しません
> （この PR では実際に「ホスト側は正常なのにコンテナ内のパスだけ壊れる」事象を踏んでいます）。

#### ネストした include（`*.secret`）は実体化しない

ホストの gitconfig はさらに別のファイルを include しています。

```ini
[include]
  path = ~/.config/git/config.secret
[includeIf "gitdir:~/work/"]
  path = ~/.config/git/config.work.secret
```

これらは**実体化も mount もしません**。リポジトリに入っているのは `.sample` だけで、
実ファイルはホスト固有の秘密情報です（`~/.config/gh` を渡さないのと同じ理由）。

コンテナ内にこのパスは存在しませんが、**include 先が「無い」または「リンク切れ」の場合、
git は黙って無視します**（`fatal` になるのは上記のループのような「アクセスを試みて失敗」
するケースだけ）。そのため渡さなくても壊れません。

```console
$ git status   # include.path = /nonexistent/foo
                # → 出力なし、終了コード 0
```

### なぜハードリンクではないのか

mise の `[dotfiles]` が持つ mode は `symlink` / `symlink-each` / `copy` / `template` で、
**ハードリンクの mode はありません**。仮にあっても、このリポジトリでは使えません。

- `git pull` / `git checkout` はファイルを「一時ファイル + rename」で書き換えるため、
  repo 側のパスが別 inode になり、**ハードリンクが黙って切れる**。両方のパスは
  存在し続けるので、気づかないまま内容が乖離する（symlink なら起きない）
- 同じ理由でアトミック保存するエディタ・ツールでも切れる。`apm` の lockfile が
  まさにこれで、`apm:sync-lock` で張り直す対応が入っている
- ディレクトリはハードリンクできないため、repo 側に増えたファイルが `~/.config` に現れない

実体化コピーはこの問題を持ちません（`initializeCommand` が毎回作り直すため、
`git pull` の後も次の起動で追従します）。

> [!TIP]
> Docker Sandboxes 側はマウント先がホストと同じ絶対パスになるので、
> **dotfiles リポジトリ自体を read-only で渡すだけ**で全ての symlink が解決します。
> 詳細は [docs/docker-sandboxes.md](./docker-sandboxes.md#ホスト設定は-symlink-なので-dotfiles-リポジトリも渡す) を参照してください。

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
（`initialize.sh`、後述）が無ければ自動生成するため、手動での鍵生成は不要です。
`devcontainer up` 実行時にこのコマンドの出力に生成した公開鍵が表示されるので、それを
GitHub に **Signing Key** として登録してください（初回のみ）:

```text
GitHub > Settings > SSH and GPG keys > New SSH key > Key type: Signing Key
```

`config/devcontainer/devcontainer.json` はこの鍵（秘密鍵・公開鍵とも）を
`/home/vscode/.ssh/id_docker_devcontainer_sign(.pub)` に読み取り専用でマウントします。
`postCreateCommand`（`post-create.sh`）が鍵の存在を検知すると、コンテナ内の
`~/.gitconfig` に以下を設定します（include で読み込んだホストの GPG 署名設定より後に
書き込まれるため、後勝ちでこちらが有効になります）:

- `gpg.format = ssh`
- `user.signingkey = ~/.ssh/id_docker_devcontainer_sign`
- `gpg.ssh.allowedSignersFile = ~/.config/git/allowed_signers`
  （`git log --show-signature`等でのローカル検証用。`user.email` と公開鍵から自動生成。
  `namespaces="git"` を付与し、この鍵が git 以外の OpenSSH 署名用途に流用されないよう制限しています）

この鍵（`~/.ssh/id_docker_devcontainer_sign`）は `initializeCommand`（`initialize.sh`）
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

`config/devcontainer/scripts/initialize.sh` は各 mount の source を種類ごとに
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

`~/.config/git/config` や `~/.config/devcontainer/scripts` のように dotfiles 適用済みなら
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
