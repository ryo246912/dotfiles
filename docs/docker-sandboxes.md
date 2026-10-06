# Docker Sandboxes (sbx)

[Docker Sandboxes](https://www.docker.com/products/docker-sandboxes/) は、AI エージェントを
microVM の中で動かすための Docker 製ツールです。CLI は `sbx`。

このリポジトリでは **AI エージェントの実行環境を devcontainer から Docker Sandboxes へ移行**しています。
`multi-worktree dev` の既定バックエンドが sandbox になり、devcontainer は `--devcontainer` で使う
フォールバック経路として残しています。

> [!IMPORTANT]
> devcontainer でできていたことのうち、**ツールチェイン（mise + 各種 CLI）とホスト連携スクリプト
> （通知・crit・plannotator・host-tmux・lefthook）は sandbox 側では未実現**です。
> 何が再現できていて何ができていないかは
> [devcontainer との機能対応表](#devcontainer-との機能対応表) にまとめています。

## devcontainer に対する利点

### 隔離境界が強い

devcontainer はコンテナなのでホストと kernel を共有します。sandbox は **microVM** で専用 kernel を
持つため、コンテナ脱出に相当する攻撃面が減ります。エージェントを `--dangerously-skip-permissions` /
`--yolo` で走らせる前提では、この差がそのまま安全余裕になります。

### ファイルシステムの露出が「渡したものだけ」になる

devcontainer の `mounts` は書けば何でも bind mount できるため、`../..` のような指定で
`$HOME` 全体が見えてしまう事故が起きます（実際に main ではその mount をやめています）。
sandbox は **workspace として明示的に渡したディレクトリしか見えません**。
`devcontainer.json` を読まないと露出範囲が分からない devcontainer と違い、
`sbx inspect` / `sbx ls` で現在の mount 範囲をそのまま確認できます。

### ネットワークが既定で制御される

devcontainer はホストのネットワークをそのまま使うため、エージェントの通信先を制限する手段が
ありません。sandbox は**全 HTTP/HTTPS がホスト側プロキシを通り**、network policy
（`open` / `balanced` / `locked down`）で許可先を制御できます。
`sbx policy log` で「何がブロックされたか」を後から追えるので、
エージェントが想定外のホストへ出ようとしたことに気付けます。

### 認証情報をエージェントに渡さずに使える

devcontainer は `GH_TOKEN` を `remoteEnv` で渡し、`~/.config/gh` を mount するため、
**エージェントが生トークンを読めます**。sandbox は `sbx secret` で OS キーチェーンに保存し、
ホスト側プロキシが送信時に注入するため、エージェントはトークンを読めません。

```bash
sbx secret set github --command 'gh auth token'
```

コミット署名も同じ発想で、**SSH agent forwarding が既定で有効**です。devcontainer では
専用の署名鍵を生成してコンテナに mount していましたが、sandbox ではホストの ssh-agent に
署名を依頼するだけなので**秘密鍵がゲストに渡りません**。

### 定義ファイルとビルドが不要

devcontainer は `devcontainer.json` の生成（`multi-worktree` が jq で合成）と Dockerfile の
ビルドが必要で、`mounts` を変えるたびに `initialize.sh` も直す必要がありました。
sandbox は CLI 引数と `[settings.sandbox]` だけで起動し、イメージビルドもありません。
宣言的に書きたい場合は `sbxenv.yaml`（後述）も選べます。

### docker daemon が最初から分離されている

devcontainer では docker-in-docker feature を有効化し、`${devcontainerId}` でスコープした
named volume を `/var/lib/docker` に当てて worktree 間の混線を防ぐ、という作り込みが必要でした。
sandbox は**最初から sandbox 専用の docker daemon** を持つため、この作り込み自体が不要です。

### 起動・破棄が軽い

`sbx run --rm` で使い捨てセッション、`sbx run -d` でバックグラウンド常駐、`sbx stop` で
インストール済みパッケージを保ったまま停止できます。`sbx prune` でまとめて掃除もできます。

### 比較表

| 項目           | devcontainer                            | Docker Sandboxes (sbx)                                        |
| -------------- | --------------------------------------- | ------------------------------------------------------------- |
| 隔離境界       | コンテナ（ホストと kernel 共有）        | microVM（専用 kernel）                                        |
| 起動方法       | `devcontainer up` + `devcontainer exec` | `sbx create` + `sbx run`                                      |
| ホスト連携     | `mounts` で任意のパスを bind mount      | workspace として渡したディレクトリのみ                        |
| マウント先パス | `devcontainer.json` の `target` で指定  | **ホストと同じ絶対パス**に固定                                |
| docker 利用    | docker-in-docker feature を有効化       | 標準で sandbox 専用 docker daemon を持つ                      |
| ポート公開     | `appPort` / `forwardPorts`              | `--publish` / `sbx ports`                                     |
| 通信制御       | 無し（ホストのネットワークに準拠）      | ホスト側プロキシで network policy を強制                      |
| 認証情報       | `~/.config/gh` などを read-only mount   | `sbx secret` で OS キーチェーンに保存し、プロキシが注入       |
| コミット署名   | 専用 SSH 鍵をコンテナに mount           | ssh-agent forwarding（秘密鍵はホストに残る）                  |
| ツールチェイン | Dockerfile + mise で固定・キャッシュ    | template / kit（このリポジトリでは**未整備**）                |
| 定義ファイル   | `config/devcontainer/devcontainer.json` | 不要（CLI 引数と `[settings.sandbox]`、任意で `sbxenv.yaml`） |

## 大きな前提の違い

1. **sandbox が見られるのは workspace として渡したディレクトリだけ。** `~/.claude/settings.json` の
   ようなユーザーレベル設定は、追加 workspace として渡さない限り sandbox 内から見えません。
2. **sandbox 内の `$HOME` はホストと別物。** 同じ絶対パスにマウントされるので、
   `~/.config/git/config` を渡しても git は自動では読みません。環境変数で明示する必要があります
   （`sbx-agent` が自動で行います）。
3. **workspace・ports・secrets・`sandboxOptions` は作成時にしか確定しない。**
   変更するには `sbx rm` して作り直します（`sbx mount` / `sbx umount` で後から足せる
   dynamic mount もありますが、`sbx-agent` は使っていません）。

## セットアップ

Docker Desktop は不要です。`sbx` は mise で管理しています（mac 専用。microVM が
Apple Silicon / Windows 11 のみ対応のため）。

```bash
# config-mac/mise/config.mac.toml の [tools] に以下が入っている
#   "github:docker/sbx-releases" = { version = "0.47.0", asset_pattern = "DockerSandboxes-darwin.tar.gz", bin_path = "bin" }
mise install
sbx version
```

aqua registry には `sbx` が未登録のため、github backend で
[docker/sbx-releases](https://github.com/docker/sbx-releases) のリリース資産を直接取得しています。
バージョンは renovate が追従します。

> [!NOTE]
> Windows(WSL2) では `sbx` を導入していません。microVM は Windows ホスト側の
> Hypervisor Platform を使うため、WSL2 の中からは利用できません。

Docker ID でサインインします。

```bash
sbx login
```

初回実行時に既定の network policy を聞かれます。AI API・npm・pip・GitHub・レジストリが
許可される `Balanced` を選んでおくのが無難です。プロンプトを出さずに設定する場合:

```bash
sbx policy set-default balanced
```

GitHub トークンは secret として登録しておきます。ホストの `gh` から都度解決されるので、
生トークンはエージェントから読めません。

```bash
sbx secret set github --command 'gh auth token'
sbx secret ls
```

ホストの agent skills を sandbox へ共有する場合は import しておきます
（`~/.claude/skills` / `~/.agents/skills` / `~/.copilot/skills` を走査します）。

```bash
sbx skills import
sbx skills ls
```

## 基本操作

```bash
# ── ライフサイクル ─────────────────────────────────────────────
sbx create --name=my-sbx claude .    # 作成のみ（アタッチしない）
sbx run --name=my-sbx claude .       # 作成してアタッチ
sbx run my-sbx                       # 既存 sandbox に再アタッチ（agent は spec から解決）
sbx run my-sbx --branch=fix-bug      # branch mode（専用 worktree で作業させる）
sbx run my-sbx -- --continue         # `--` 以降は agent へ pass-through
sbx run --rm claude                  # セッション終了時に sandbox を削除
sbx run -d --name=my-sbx claude .    # バックグラウンド常駐（ポート公開したまま使う）
sbx ls                               # 一覧
sbx inspect my-sbx                   # mount・リソース・ポートを確認
sbx stop my-sbx                      # 停止（インストール済みパッケージは保持）
sbx rm my-sbx                        # 削除（VM と .sbx/ 配下の worktree も消える）
sbx prune                            # 使っていない sandbox をまとめて削除

# ── シェル・デバッグ ───────────────────────────────────────────
sbx exec -it my-sbx bash             # sandbox 内でシェルを開く（ホスト側の端末から）
sbx exec my-sbx bash -c "cmd"        # 単発コマンド（-d / --detach は非対応）
sbx cp ./a.json my-sbx:/path/        # ファイル転送

# ── ポートフォワード ───────────────────────────────────────────
sbx ports my-sbx --publish 8080:8000
sbx ports my-sbx                     # 現在の公開ポート一覧
sbx ports my-sbx --unpublish 8080:8000

# ── network policy ─────────────────────────────────────────────
sbx policy ls
sbx policy log my-sbx                # 何がブロックされたかを確認
sbx policy allow network "*.npmjs.org,*.pypi.org"

# ── 認証情報 / skills / MCP ────────────────────────────────────
sbx secret set github --command 'gh auth token'
sbx skills import                    # ホストの skills を共有 store へ取り込む
sbx mcp add <name> --url <url>       # MCP サーバを gateway 経由で共有

# ── TUI ────────────────────────────────────────────────────────
sbx                                  # ダッシュボード（c:作成 / Enter:アタッチ / x:シェル / r:削除）
```

追加 workspace は `sbx run <agent> <primary> <extra>...` の形で渡します。
`:ro` を付けると read-only になり、単一ファイルも指定できます。

```bash
sbx run --name=my-sbx claude ~/dev/app ~/dev/libs:ro ~/.config/git/config:ro
```

## このリポジトリでの使い方

### `sbx-agent` ラッパー

`local/bin/sbx-agent`（適用後: `~/.local/bin/sbx-agent`）が **sbx 呼び出しの単一実装**です。
ccmanager のプリセットと `multi-worktree dev` の両方がこれを経由します。

```bash
sbx-agent claude                              # カレントディレクトリを workspace に起動
sbx-agent codex -- resume --yolo              # agent に引数を pass-through
sbx-agent claude --config-dir ~/.claude-work3 --name-suffix w3
sbx-agent claude --branch=auto                # branch mode
sbx-agent claude --rm                         # セッション終了時に削除
sbx-agent claude --skills=off                 # 共有 skills を渡さない
sbx-agent claude --publish 7842:7842          # ポート公開
sbx-agent claude --mount ~/dev/libs:ro        # 追加 workspace
sbx-agent --help
```

やっていること:

1. sandbox 名を `<repo>-<branch>-<agent>[-<suffix>]` から生成する
   （hostname 相当なので英数字とハイフンに正規化し、63 文字に切り詰める）
2. 同名の sandbox が無ければ `sbx create` で作成する。このとき
   `~/.config/git/config:ro` / `~/.config/git/gitignore:ro` / `~/.config/gh:ro` /
   `~/.aws/config:ro` / `~/.agents:ro` と agent の設定ディレクトリを追加 workspace として渡す
   （`devcontainer.json` の `mounts` に対応）
3. workspace が linked worktree なら、その common git dir（実体リポジトリの `.git`）も
   追加 workspace として渡す（[後述](#worktree-と-git-metadata-の-mount)）
4. `--env` で devcontainer の `remoteEnv` 相当（`AI_AGENT` / `TERM` / `HOST_USER` /
   `LEFTHOOK_CONFIG` / `MISE_TRUSTED_CONFIG_PATHS`）と agent の設定ディレクトリ
   （`CLAUDE_CONFIG_DIR` / `CODEX_HOME`）を渡す
5. 同じく `--env` で `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` を渡し、
   ホストの git 設定とコミット署名を設定する（[後述](#ホストの-git-設定とコミット署名)）
6. `sbx run <name>` でアタッチする

agent ごとの設定ディレクトリの対応（`--config-dir` で上書き可）:

| agent   | 設定ディレクトリ | sandbox 内で参照させる環境変数 |
| ------- | ---------------- | ------------------------------ |
| claude  | `~/.claude`      | `CLAUDE_CONFIG_DIR`            |
| codex   | `~/.codex`       | `CODEX_HOME`                   |
| copilot | `~/.copilot`     | （マウントのみ）               |

`SBX_AGENT_MOUNTS` に `,` 区切りでパスを並べると、追加 workspace をまとめて指定できます
（`:` は read-only 指定の `:ro` と衝突するため区切り文字は `,`）。

### `multi-worktree dev`

`multi-worktree dev` の既定バックエンドが Docker Sandboxes です。
task root（全リポジトリの worktree をまとめた親ディレクトリ）が primary workspace になり、
`sbx-agent` に委譲します。

```bash
multi-worktree dev feat/add-auth                      # 既定 agent を sandbox で起動
multi-worktree dev feat/add-auth claude               # agent を指定
multi-worktree dev feat/add-auth codex -- --continue  # agent に引数を pass-through
multi-worktree dev feat/add-auth claude --branch=auto # branch mode
multi-worktree dev feat/add-auth --new                # sandbox を作り直す
multi-worktree dev feat/add-auth --rm                 # 終了時に sandbox を削除
multi-worktree dev feat/add-auth --name=my-sbx        # sandbox 名を明示
multi-worktree dev feat/add-auth --devcontainer ccmanager  # devcontainer backend
```

設定は `~/.config/multi-worktree/config.toml` の `[settings.sandbox]` で行います。

```toml
[settings.sandbox]
# dev サブコマンドの既定バックエンド（"sbx" | "devcontainer"）
backend = "sbx"
# agent 名を省略したときに起動する agent
default_agent = "claude"
# sandbox 名の接頭辞（sandbox 名は <prefix>-<task>-<agent>）
name_prefix = "mw"
# 共有 skills store の扱い（off | readonly | readwrite）
skills = "readonly"
# sandbox template の OCI 参照（空なら sbx の既定 template）
# template = "docker.io/docker/sandbox-templates:claude-code"
# リソース上限
# cpus = "4"
# memory = "8g"
# 公開ポート（host:sandbox）
# publish_ports = ["7842:7842"]
# task root に加えてマウントする workspace（sbx-agent の既定分は書かなくてよい）
extra_workspaces = [
  "~/.coderabbit",
]
```

`backend = "devcontainer"` にすると従来どおり `devcontainer up` / `devcontainer exec` が既定になります。

### ccmanager

`config/ccmanager/config.json` の `commandPresets` に、通常 preset と 1:1 対応する
sandbox preset を用意しています。claude は account ごとに別 sandbox になります
（env は作成時に固定されるため、`--name-suffix` で名前を分けています）。

| preset id      | 起動内容                                                            |
| -------------- | ------------------------------------------------------------------- |
| `sbx`          | `sbx-agent claude`（`~/.claude`）                                   |
| `sbx-account2` | `sbx-agent claude --config-dir ~/.claude-account2 --name-suffix a2` |
| `sbx-work3`    | `sbx-agent claude --config-dir ~/.claude-work3 --name-suffix w3`    |
| `sbx-codex`    | `sbx-agent codex -- resume --yolo`                                  |
| `sbx-copilot`  | `sbx-agent copilot -- --resume --yolo`                              |

## worktree と Git metadata の mount

`multi-worktree` の task root には各リポジトリの **linked worktree** が並びます。linked worktree の
`.git` は file であり、実体リポジトリの common git dir（`<repo>/.git`）を**絶対パス**で参照します。
task root だけを workspace として渡すと、sandbox 内から common git dir が見えず git が壊れます
（公式ドキュメントも
[Host worktree](https://docs.docker.com/ai/sandboxes/workflows/git/) の制限として
「`.git` pointer file を解決できず git が使えない」と明記しています）。

sbx はホストと同じ絶対パスに workspace をマウントするため、common git dir を追加 workspace として
渡せばホスト・sandbox のどちらでも同じパスで git が解決できます。`multi-worktree dev` と `sbx-agent` は
`git rev-parse --path-format=absolute --git-common-dir` でこれを解決して自動で渡します。
devcontainer 側の mount 範囲と同じ考え方で、詳細は
[docs/devcontainer.md](./devcontainer.md) の「workspace と Git metadata の mount 範囲」を参照してください。

- 実体リポジトリの working tree や兄弟ディレクトリは渡さないので、sandbox からは見えません
- relative-paths 形式の worktree（`git worktree add --relative-paths` /
  `worktree.useRelativePaths`）は絶対パス mount では解決できないため、warn を出してスキップします
- `--clone`（clone mode）は **main 以外の worktree からは使えません**。sbx 側が
  「read-only bind mount が worktree の `.git` pointer file を解決できない」として拒否するため、
  multi-worktree の task root では利用できません

## ホストの git 設定とコミット署名

sandbox 内の `$HOME` はホストとは別物なので、`~/.config/git/config` を mount しただけでは
git に読まれません。`sbx-agent` は `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n`
で以下を注入します（devcontainer の `post-create.sh` と同じ内容）。

| 設定                                   | 目的                                                        |
| -------------------------------------- | ----------------------------------------------------------- |
| `include.path`                         | ホストの `~/.config/git/config`（`user.name` 等）を取り込む |
| `core.excludesfile`                    | ホストのグローバル gitignore を使う                         |
| `credential.https://github.com.helper` | `!gh auth git-credential` で gh の認証を使う                |
| `url.https://github.com/.insteadOf`    | SSH 形式の remote を HTTPS に書き換える                     |
| `gc.worktreePruneExpire`               | 見えていない worktree を git gc が消さないようにする        |

コミット署名は **SSH agent forwarding**（sbx の既定で有効）を使います。
ホストのパスは sandbox 内に存在しないため、鍵ファイルではなく forwarded agent の公開鍵を
`key::<pubkey>` 形式で `user.signingkey` に設定します。

```
gpg.format      = ssh
user.signingkey = key::<ssh-add -L の 1 行目>
commit.gpgsign  = true
```

ホストの ssh-agent に鍵が無い場合は `commit.gpgsign = false` にして警告します。
ホストの gitconfig が GPG 署名を有効にしていても GPG 秘密鍵は sandbox に渡らないため、
無効化しないと commit が毎回失敗するからです。`ssh-add ~/.ssh/id_ed25519` で鍵を登録してください。

> [!NOTE]
> devcontainer では `gpg.ssh.allowedSignersFile` も設定して署名の検証までできるようにしていましたが、
> sandbox 側では未設定です（署名の作成のみ）。

## devcontainer との機能対応表

凡例: ✅ 再現済み / ⚠️ 部分的・要設定 / ❌ 未実現

### initializeCommand（`initialize.sh`）

| devcontainer でやっていたこと    | sandbox                                                                          |
| -------------------------------- | -------------------------------------------------------------------------------- |
| mount source の事前作成          | ✅ 不要。`sbx-agent` は存在しないパスを警告してスキップする                      |
| 通知用 SSH 鍵の生成              | ❌ 通知経路そのものが未実現（後述）                                              |
| 署名用 SSH 鍵の生成・`.pub` 同期 | ✅ 不要。ssh-agent forwarding でホストの鍵をそのまま使う（秘密鍵はホストに残る） |

### Dockerfile / features

| devcontainer でやっていたこと                                       | sandbox                                                             |
| ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| docker-in-docker feature                                            | ✅ 標準で sandbox 専用 docker daemon を持つ                         |
| DinD データを `${devcontainerId}` スコープの named volume に分離    | ✅ 不要。sandbox ごとに独立（`sbx rm` で消える）                    |
| Ubuntu 24.04 + zsh                                                  | ⚠️ 既定 template は Ubuntu だが zsh は無い（`sbx exec` は bash）    |
| mise + 約 40 ツール（claude/codex/copilot/crit/lint 群/言語処理系） | ❌ **未実現**。既定 template は git / gh / node / go / python3 程度 |
| mise cache mount によるリビルド高速化                               | ❌ 未実現（相当するのは template キャッシュ / kit）                 |
| `crit` ラッパーを mise shim より前の PATH に置く                    | ❌ 未実現（crit 自体が未導入）                                      |

ツールチェインは **custom template か kit** で持ち込む必要があります。
`sbx-agent --template` / `[settings.sandbox].template` で指定できる口は用意していますが、
**このリポジトリ用の template / kit はまだ作っていません**。

### mounts

| devcontainer の mount                     | sandbox                                                       |
| ----------------------------------------- | ------------------------------------------------------------- |
| `~/.config/git/config`                    | ✅ `:ro` で渡し、`include.path` で取り込む                    |
| `~/.config/git/gitignore`                 | ✅ `:ro` で渡し、`core.excludesfile` に設定                   |
| `~/.config/gh`                            | ✅ `:ro`。加えて `sbx secret set github` でトークン注入も可能 |
| `~/.aws/config`                           | ✅ `:ro`                                                      |
| `~/.agents`                               | ✅ `:ro`                                                      |
| `~/.claude` / `~/.codex` / `~/.copilot`   | ✅ agent ごとに rw で渡す                                     |
| `~/.claude-account2` / `~/.claude-work3`  | ✅ `--config-dir` で切り替え（preset ごとに別 sandbox）       |
| workspace をホストと同じ絶対パスに mount  | ✅ sbx の標準動作                                             |
| common git dir（実体リポジトリの `.git`） | ✅ 追加 workspace として自動で渡す                            |
| `~/.config/ccusage` / `~/.config/mise`    | ⚠️ 既定では渡していない（`extra_workspaces` で追加可）        |
| `~/.ssh/known_hosts`                      | ⚠️ 既定では渡していない                                       |
| `~/.coderabbit`                           | ⚠️ `extra_workspaces` で追加する                              |
| `~/.claude/settings.json` だけ read-only  | ❌ ディレクトリ全体を rw で渡している                         |
| `~/.claude.json`（コピー元）              | ❌ 未実現                                                     |
| `~/.config/devcontainer`（スクリプト群）  | ❌ スクリプト自体が未移植のため不要                           |

### remoteEnv / ポート

| devcontainer                                                                        | sandbox                                                                                                            |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `AI_AGENT` / `TERM` / `HOST_USER` / `LEFTHOOK_CONFIG` / `MISE_TRUSTED_CONFIG_PATHS` | ✅ `--env` で渡す                                                                                                  |
| `GH_TOKEN`（build secret + remoteEnv）                                              | ✅ `sbx secret set github --command 'gh auth token'` で代替                                                        |
| `appPort: 127.0.0.1::7842`（crit UI）                                               | ⚠️ `publish_ports` / `sbx ports` で公開可。host port の自動採番と `~/.crit-host-port` への記録・ホスト通知は未実現 |
| `CRIT_*`                                                                            | ❌ crit 未導入のため未設定                                                                                         |
| `PLANNOTATOR_*`                                                                     | ❌ 未実現                                                                                                          |

### postCreateCommand（`post-create.sh`）

| devcontainer でやっていたこと                                                                     | sandbox                                                                                  |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `include.path` / `core.excludesfile` / credential helper / `insteadOf` / `gc.worktreePruneExpire` | ✅ `GIT_CONFIG_*` で注入                                                                 |
| コミット署名（専用鍵 + `allowed_signers`）                                                        | ⚠️ ssh-agent forwarding で署名はできる。`allowed_signers`（検証側）は未設定              |
| `mount-container-only-dirs.sh`（`node_modules` / `.venv` / `target` をコンテナローカルへ分離）    | ❌ **未実現**。direct mode は workspace をホストと共有するため、生成物がホストに書かれる |
| 各リポジトリへの `lefthook.local.yml` 配置と `lefthook install`                                   | ❌ 未実現（lefthook 自体が未導入）                                                       |
| `~/.claude.json` のコピー                                                                         | ❌ 未実現                                                                                |
| `~/.claude-account2` / `-work3` への `projects`/`settings.json`/`agents`/`skills` symlink 共有    | ❌ 未実現（`--config-dir` で別ディレクトリを渡すだけ）                                   |
| `~/.crit.config.json` の生成                                                                      | ❌ 未実現                                                                                |

### postStartCommand（`post-start.sh`）

| devcontainer でやっていたこと            | sandbox                                         |
| ---------------------------------------- | ----------------------------------------------- |
| `mise trust`                             | ✅ 不要。`MISE_TRUSTED_CONFIG_PATHS` で代替     |
| 生成物ディレクトリの bind mount 再張り   | ❌ 上記 `mount-container-only-dirs.sh` が未実現 |
| `mac-host` への SSH config 生成          | ❌ 未実現                                       |
| crit の host port 取得・記録・ホスト通知 | ❌ 未実現                                       |

### コンテナ内でできていたこと

| できていたこと                                    | sandbox                                                                                                 |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `docker compose` で DB 等を建てる                 | ✅ sandbox 専用 docker daemon で可能                                                                    |
| 共有 skills（`~/.claude/skills`）                 | ✅ `sbx skills import` + `--skills=readonly` で共有                                                     |
| ホスト macOS への通知（SSH → `macos-notify-cli`） | ❌ **未実現**。`localhost` はホストを指さないため `host.docker.internal` と network policy の許可が必要 |
| crit のレビュー UI                                | ❌ 未実現（crit 未導入 + host port 通知が未実現）                                                       |
| plannotator の SSH reverse tunnel                 | ❌ 未実現                                                                                               |
| `host-tmux`（ホスト tmux pane の参照）            | ❌ 未実現                                                                                               |
| `ai-rule-hook`（セッション終了時のルール提案）    | ⚠️ `~/.claude` を渡しているので hooks 定義は読まれるが、スクリプト本体が無いため動かない                |
| lefthook の pre-commit lint 一式                  | ❌ 未実現（lint ツールと lefthook が未導入）                                                            |
| `mise run lint:*` / `fix:*`                       | ❌ 未実現（mise と tasks が未導入）                                                                     |

### まとめ

- **再現できている**: 隔離・workspace の見え方・git 設定・コミット署名・agent 設定ディレクトリ・
  docker daemon・skills 共有・認証情報の受け渡し（むしろ devcontainer より安全）
- **未実現の中心は 2 つ**:
  1. **ツールチェイン**（mise + 各種 CLI）。custom template か kit を作る必要がある
  2. **ホスト連携スクリプト**（通知 / crit / plannotator / host-tmux / lefthook）。
     sandbox は network policy 下にあるため、ホストへの SSH 経路の設計からやり直しになる
- そのため **lint を回したり crit でレビューしたりする用途では、今は devcontainer backend
  （`--devcontainer`）の方が揃っています**。sandbox は「隔離環境でエージェントにコードを
  触らせる」用途に向いています。

## まだ使っていない sbx の機能

必要になったら使えるもののうち、現時点で `sbx-agent` に組み込んでいないもの。

### `sbxenv.yaml`（宣言的な環境定義）

`devcontainer.json` に最も近い仕組みで、workspace・追加 workspace・`env`・ports・secrets・
MCP・kits・リソース上限・ホスト側 lifecycle コマンド（`initialize` / `postCreate` / `preRemove`）を
1 ファイルで宣言できます。`~/.sbxenv.yaml` にユーザー既定を置き、
`workspace: ${{ env.projectDir }}` でプロジェクトごとに使い回すこともできます。

```yaml
schemaVersion: "1"
name: web-app
agent: claude
workspace: ./web-app
additionalWorkspaces:
  - path: ./shared-libs
    readOnly: true
env:
  AI_AGENT: "1"
secrets:
  github:
    command: gh auth token
ports:
  - sandbox: 7842
    host: 7842
sandboxOptions:
  memory: 8g
  skills: readonly
```

採用していない理由は、**`sbx env` が experimental で、かつ lifecycle コマンドや
credential command を含む plan は毎回承認が必要**なため、ccmanager から非対話で起動する
経路と相性が悪いことです（`--auto-approve` / `env.rememberHostCommands` で緩められますが、
CLI 引数の方が挙動が読めます）。安定したら移行候補です。

### kits（v3）

OCI パッケージで「workload（ベース環境とコマンド）＋ mixin（ツール・設定・認証・network 許可・
エージェント向け指示）」を合成する仕組み。devcontainer の Dockerfile + features に相当します。
**上記の未実現項目（ツールチェイン）を解決する本筋はこれ**です。
`sbx kit validate` でチェックし、kit set として publish できます。

コミット署名を自動設定する
[`git-ssh-sign`](https://github.com/docker/sbx-kits-contrib/tree/main/git-ssh-sign)
のような community kit もあります（`sbx settings set kit.allowedSources` で許可が必要）。

### その他

| 機能                       | 概要                                                                       |
| -------------------------- | -------------------------------------------------------------------------- |
| `sbx mcp`                  | MCP サーバを一度登録して gateway 経由で各 sandbox / agent から使い回す     |
| `sbx template save/load`   | sandbox のコンテナ FS を template 化して再利用（手で入れたツールを固定化） |
| `sbx mount` / `sbx umount` | 作成後に workspace を追加・削除する dynamic mount（再起動後も復元される）  |
| `sbx run --model`          | ローカル / 任意の OpenAI・Anthropic 互換エンドポイントのモデルを使う       |
| `sbx --cloud`              | Docker 管理のクラウド上で sandbox を動かす（要サブスクリプション）         |
| `sbx run --clone`          | sandbox 内の専用 clone で作業させる（main worktree からのみ利用可）        |
| `sbx diagnose`             | 環境診断（`mkfs.erofs` のブロックサイズ等まで見る）                        |

## 制限・注意点

- workspace・ports・secrets・`sandboxOptions` は **sandbox 作成時にしか確定しない**。
  変えたいときは `sbx rm` して作り直す（`sbx mount` を使えば mount だけは後から足せる）。
- `sbx exec -d` / `--detach` は **非対応**（0.45.0 で即エラーになった）。
  作成後に sandbox 内で何かを設定したい場合は前景の `sbx exec` を使うか、
  `--env` / `/etc/sandbox-persistent.sh` を使う。
- workspace の外を指すシンボリックリンクは追えない。設定ファイルは実体を渡すかコピーする。
- グローバル secret は sandbox 作成時に注入される。実行中の sandbox には後から反映されない。
- 公開ポートは stop/restart で消えるため、再起動後に `sbx ports` を打ち直す。
- `sbx run` が既存 sandbox に再アタッチする場合、`--publish` は無視される。
- sandbox 内のサービスは `127.0.0.1` ではなく `0.0.0.0` に bind させる（でないと公開ポートに届かない）。
- ラップトップをスリープさせると sandbox の時刻がずれて TLS やトークンが失敗することがある。
  `sbx stop` → `sbx run` で復旧する。
- カスタム template のビルドにはホスト側の Docker daemon が必要（sandbox 内ではビルドできない）。
- `--skills=readwrite` の sandbox は他の sandbox が読む skills を書き換えられる。
  信頼境界を分けたい場合は `--skills=off`。

## トラブルシューティング

| 症状                           | 対処                                                                                |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| パッケージが取得できない       | `sbx policy log` でブロック先を確認し `sbx policy allow network <host>` で許可      |
| `You are not authenticated`    | `sbx login` で再認証                                                                |
| モデル API に到達できない      | `sbx policy allow network api.anthropic.com`。secret 登録後なら sandbox を再作成    |
| ポートフォワードが効かない     | サービスが `0.0.0.0` に bind しているか確認し、`sbx ports` をホスト端末で実行       |
| agent がホストの設定を読まない | 設定ディレクトリを追加 workspace に渡し、`CLAUDE_CONFIG_DIR` 等を `--env` で明示    |
| コミットが署名されない         | `ssh-add -L` で鍵が見えるか確認（forwarding はホストの ssh-agent が前提）           |
| sandbox 内で git が使えない    | linked worktree の common git dir が渡っているか確認（relative-paths 形式は非対応） |
| 時刻ずれでトークンが失敗する   | `sbx stop` → `sbx run` で再起動                                                     |

## 参考

- [Docker Sandboxes（製品ページ）](https://www.docker.com/products/docker-sandboxes/)
- [Docker Sandboxes ドキュメント](https://docs.docker.com/ai/sandboxes/)
- [リリースノート](https://docs.docker.com/ai/sandboxes/release-notes/) / [docker/sbx-releases](https://github.com/docker/sbx-releases)
- [sbx CLI リファレンス](https://docs.docker.com/reference/cli/sbx/)
- [環境ファイル（`sbxenv.yaml`）](https://docs.docker.com/ai/sandboxes/configuration/environment-files/)
- [kits（カスタマイズ）](https://docs.docker.com/ai/sandboxes/customize/)
- [docs/multi-worktree.md](multi-worktree.md) - multi-worktree との統合
- [docs/devcontainer.md](devcontainer.md) - 旧バックエンド（devcontainer）の仕組み
