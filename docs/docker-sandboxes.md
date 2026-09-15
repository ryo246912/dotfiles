# Docker Sandboxes (sbx)

[Docker Sandboxes](https://www.docker.com/products/docker-sandboxes/) は、AI エージェントを
microVM の中で動かすための Docker 製ツールです。CLI は `sbx`。

このリポジトリでは **AI エージェントの実行環境を devcontainer から Docker Sandboxes へ移行**しています。
`multi-worktree dev` の既定バックエンドが sandbox になり、devcontainer は `--devcontainer` で使う
フォールバック経路として残しています。

## devcontainer との違い

| 項目           | devcontainer                                | Docker Sandboxes (sbx)                                  |
| -------------- | ------------------------------------------- | ------------------------------------------------------- |
| 隔離境界       | コンテナ（ホストと kernel 共有）            | microVM（専用 kernel）                                  |
| 起動方法       | `devcontainer up` + `devcontainer exec`     | `sbx create` + `sbx run`                                |
| ホスト連携     | `mounts` で任意のパスを bind mount          | workspace として渡したディレクトリのみ                  |
| マウント先パス | `devcontainer.json` の `target` で指定      | **ホストと同じ絶対パス**に固定                          |
| docker 利用    | docker-in-docker feature を有効化           | 標準で sandbox 専用 docker daemon を持つ                |
| ポート公開     | `appPort` / `forwardPorts`                  | `sbx ports <name> --publish <host>:<sandbox>`           |
| 通信制御       | 無し（ホストのネットワークに準拠）          | ホスト側プロキシで network policy を強制                |
| 認証情報       | `~/.config/gh` などを read-only mount       | `sbx secret` で OS キーチェーンに保存し、プロキシが注入 |
| 定義ファイル   | `dot_config/devcontainer/devcontainer.json` | 不要（CLI 引数と `[settings.sandbox]` で指定）          |

大きな前提の違いは 2 つです。

1. **sandbox が見られるのは workspace として渡したディレクトリだけ。** `~/.claude/settings.json` の
   ようなユーザーレベル設定は、追加 workspace として渡さない限り sandbox 内から見えません。
2. **workspace は sandbox 作成時にしか指定できない。** 後からマウントを追加することはできず、
   `sbx rm` して作り直す必要があります。

## セットアップ

Docker Desktop は不要です。

```bash
# macOS (Apple Silicon)
brew install docker/tap/sbx

# Windows 11 (x86_64)
# 事前に Hypervisor Platform を有効化しておく
#   Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All
winget install -h Docker.sbx
```

Docker ID でサインインします。

```bash
sbx login
```

初回実行時に既定の network policy を聞かれます。AI API・npm・pip・GitHub・レジストリが
許可される `Balanced` を選んでおくのが無難です。プロンプトを出さずに設定する場合:

```bash
sbx policy set-default balanced
```

GitHub トークンはグローバル secret として登録しておきます。
**グローバル secret は sandbox 作成時に注入される**ため、sandbox を作る前に登録してください。

```bash
echo "$(gh auth token)" | sbx secret set -g github
sbx secret ls
```

## 基本操作

```bash
# ── ライフサイクル ─────────────────────────────────────────────
sbx create --name=my-sbx claude .    # 作成のみ（アタッチしない）
sbx run --name=my-sbx claude .       # 作成してアタッチ
sbx run my-sbx                       # 既存 sandbox に再アタッチ（agent は spec から解決）
sbx run my-sbx --branch=fix-bug      # branch mode（専用 worktree で作業させる）
sbx run my-sbx -- --continue         # `--` 以降は agent へ pass-through
sbx ls                               # 一覧
sbx stop my-sbx                      # 停止（インストール済みパッケージは保持）
sbx rm my-sbx                        # 削除（VM と .sbx/ 配下の worktree も消える）

# ── シェル・デバッグ ───────────────────────────────────────────
sbx exec -it my-sbx bash             # sandbox 内でシェルを開く（ホスト側の端末から）
sbx exec -d my-sbx bash -c "cmd"     # 単発コマンド

# ── ポートフォワード ───────────────────────────────────────────
sbx ports my-sbx --publish 8080:8000
sbx ports my-sbx                     # 現在の公開ポート一覧
sbx ports my-sbx --unpublish 8080:8000

# ── network policy ─────────────────────────────────────────────
sbx policy ls
sbx policy log my-sbx                # 何がブロックされたかを確認
sbx policy allow network "*.npmjs.org,*.pypi.org"

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

`dot_local/bin/sbx-agent`（適用後: `~/.local/bin/sbx-agent`）は、
devcontainer でやっていた「ホストの agent 設定をマウントして隔離環境で動かす」を
`sbx` で再現するラッパーです。ccmanager のプリセットからも呼ばれます。

```bash
sbx-agent claude                          # カレントディレクトリを workspace に起動
sbx-agent codex -- resume --yolo          # agent に引数を pass-through
sbx-agent claude --branch=auto            # branch mode
sbx-agent claude --new                    # 既存 sandbox を再利用せず作り直す
sbx-agent claude --mount ~/dev/libs:ro    # 追加 workspace
sbx-agent --help
```

やっていること:

1. sandbox 名を `<repo>-<branch>-<agent>` から生成する（hostname 相当なので英数字とハイフンに正規化）
2. 同名の sandbox が無ければ `sbx create` で作成する。このとき
   `~/.config/git/config:ro` / `~/.config/gh:ro` / `~/.agents:ro` と agent の設定ディレクトリを
   追加 workspace として渡す
3. 作成直後に `CLAUDE_CONFIG_DIR` / `CODEX_HOME` を `/etc/sandbox-persistent.sh` へ書き込み、
   sandbox 内の agent がホストの設定ディレクトリを読むようにする
4. `sbx run <name>` でアタッチする

agent ごとの設定ディレクトリの対応:

| agent   | 設定ディレクトリ | sandbox 内で参照させる環境変数 |
| ------- | ---------------- | ------------------------------ |
| claude  | `~/.claude`      | `CLAUDE_CONFIG_DIR`            |
| codex   | `~/.codex`       | `CODEX_HOME`                   |
| copilot | `~/.copilot`     | （マウントのみ）               |
| gemini  | `~/.gemini`      | （マウントのみ）               |

`SBX_AGENT_MOUNTS` に `,` 区切りでパスを並べると、追加 workspace をまとめて指定できます
（`:` は read-only 指定の `:ro` と衝突するため区切り文字は `,`）。

### `multi-worktree dev`

`multi-worktree dev` の既定バックエンドが Docker Sandboxes です。
task root（全リポジトリの worktree をまとめた親ディレクトリ）が primary workspace になります。

```bash
multi-worktree dev feat/add-auth                      # 既定 agent を sandbox で起動
multi-worktree dev feat/add-auth claude               # agent を指定
multi-worktree dev feat/add-auth codex -- --continue  # agent に引数を pass-through
multi-worktree dev feat/add-auth claude --branch=auto # branch mode
multi-worktree dev feat/add-auth --new                # sandbox を作り直す
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
# sandbox template の OCI 参照（空なら sbx の既定 template）
# template = "docker.io/docker/sandbox-templates:claude-code"
# task root に加えてマウントする workspace
extra_workspaces = [
  "~/.config/git/config:ro",
  "~/.config/gh:ro",
  "~/.agents",
]
```

`backend = "devcontainer"` にすると従来どおり `devcontainer up` / `devcontainer exec` が既定になります。

### ccmanager

`dot_config/ccmanager/config.json` の `commandPresets` に `sbx-agent` 経由のプリセットを用意しています。

| preset id     | 起動内容                               |
| ------------- | -------------------------------------- |
| `sbx`         | `sbx-agent claude`                     |
| `sbx-codex`   | `sbx-agent codex -- resume --yolo`     |
| `sbx-copilot` | `sbx-agent copilot -- --resume --yolo` |
| `sbx-gemini`  | `sbx-agent gemini -- -s`               |

## devcontainer からの移行メモ

- **bind mount → 追加 workspace**: `devcontainer.json` の `mounts` に相当するものは
  `sbx run` / `sbx create` の追加 workspace 引数です。読み取り専用は `,readonly` ではなく `:ro`。
- **マウント先が変わる**: devcontainer は `target` で `/home/vscode/...` に置き換えていましたが、
  sbx はホストと同じ絶対パスにマウントします。`$HOME` 依存の設定探索は効かないので、
  `CLAUDE_CONFIG_DIR` などで明示する必要があります（`sbx-agent` が自動で行います）。
- **DinD feature は不要**: sandbox は最初から専用の docker daemon を持っているため、
  `docker compose up` がそのまま動きます。`/var/lib/docker` の named volume 分離も不要です。
- **`appPort` → `sbx ports`**: crit のようにホストのブラウザから開く UI は
  `sbx ports <name> --publish <host>:<sandbox>` で公開します。sandbox 内のサービスは
  `127.0.0.1` ではなく `0.0.0.0` に bind させてください。
- **ホストへの SSH 通知**: sandbox 内から `localhost` はホストを指しません。
  ホストのサービスへは `host.docker.internal` を使い、`sbx policy allow network localhost:<port>` で
  許可します。
- **`GH_TOKEN` の受け渡し**: devcontainer では `remoteEnv` + build secret でしたが、
  sandbox では `sbx secret set -g github` で登録するとプロキシが自動注入します。

## 制限・注意点

- workspace は **sandbox 作成時にしか指定できない**。マウントを増やしたいときは `sbx rm` して作り直す。
- workspace の外を指すシンボリックリンクは追えない。設定ファイルは実体をマウントするかコピーする。
- グローバル secret は sandbox 作成時に注入される。実行中の sandbox には後から反映されない。
- 公開ポートは stop/restart で消えるため、再起動後に `sbx ports` を打ち直す。
- ラップトップをスリープさせると sandbox の時刻がずれて TLS やトークンが失敗することがある。
  `sbx stop` → `sbx run` で復旧する。
- カスタム template のビルドにはホスト側の Docker daemon が必要（sandbox 内ではビルドできない）。

## トラブルシューティング

| 症状                           | 対処                                                                             |
| ------------------------------ | -------------------------------------------------------------------------------- |
| パッケージが取得できない       | `sbx policy log` でブロック先を確認し `sbx policy allow network <host>` で許可   |
| `You are not authenticated`    | `sbx login` で再認証                                                             |
| モデル API に到達できない      | `sbx policy allow network api.anthropic.com`。secret 登録後なら sandbox を再作成 |
| ポートフォワードが効かない     | サービスが `0.0.0.0` に bind しているか確認し、`sbx ports` をホスト端末で実行    |
| agent がホストの設定を読まない | 設定ディレクトリを追加 workspace に渡し、`CLAUDE_CONFIG_DIR` 等を明示            |
| Windows で docker が使えない   | `--template docker.io/docker/sandbox-templates:claude-code-docker` を指定        |

## 参考

- [Docker Sandboxes（製品ページ）](https://www.docker.com/products/docker-sandboxes/)
- [sbx CLI リファレンス](https://docs.docker.com/reference/cli/sbx/)
- [Docker Sandboxes クイックスタート（dockersamples/sbx-quickstart）](https://github.com/dockersamples/sbx-quickstart)
- [docs/multi-worktree.md](multi-worktree.md) - multi-worktree との統合
- [docs/devcontainer.md](devcontainer.md) - 旧バックエンド（devcontainer）の仕組み
