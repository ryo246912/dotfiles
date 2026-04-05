# multi-worktree

マルチリポジトリ × git worktree 管理ツールです。複数のリポジトリに対して、タスク単位で worktree を一括作成し、共通の task root 配下でまとめて扱えます。

Go 実装本体は source-only の [`tools/multi-worktree/`](../../tools/multi-worktree) にあり、chezmoi で配布する `multi-worktree` コマンドは薄い wrapper として `go run` でその実装を起動します。将来はこのディレクトリをそのまま別リポジトリへ切り出す想定です。

## 構成

- `dot_local/bin/executable_multi-worktree`
  - エントリポイント。source state から Go 実装を起動します。
- `tools/multi-worktree/`
  - Go モジュール本体。CLI / config / git/worktree 操作 / scaffold を含みます。
- `dot_config/multi-worktree/config.toml.sample`
  - 設定ファイルのサンプルです。
- `dot_config/multi-worktree/completion.bash`
  - Bash 補完です。
- `dot_config/multi-worktree/_multi-worktree`
  - Zsh 補完です。

## セットアップ

```bash
mkdir -p ~/.config/multi-worktree
cp ~/.config/multi-worktree/config.toml.sample ~/.config/multi-worktree/config.toml
$EDITOR ~/.config/multi-worktree/config.toml
```

`multi-worktree` は source state にある Go モジュールを参照して動きます。通常は `~/.local/share/chezmoi/tools/multi-worktree/` を見に行きますが、別の場所を使う場合は `MULTI_WORKTREE_SOURCE_DIR` で上書きできます。

## 補完

```bash
# Bash
source ~/.config/multi-worktree/completion.bash

# Zsh
fpath=(~/.config/multi-worktree $fpath)
autoload -Uz compinit && compinit
```

## 設定ファイル

`~/.config/multi-worktree/config.toml` の例:

```toml
[groups.default]
repos = [
  "~/dev/repo-a",
  "~/dev/repo-b",
]
base_dir = "../worktrees"
worktree_prefix = "multi-worktree"

[groups.work]
repos = [
  "~/work/frontend",
  "~/work/backend",
  "~/work/infra",
]
base_dir = "../worktrees"
worktree_prefix = "multi-worktree"

[groups.default.devcontainer]
up_opts = [
  "--workspace-folder",
  ".",
  "--config",
  "$HOME/.config/devcontainer/devcontainer.json",
]
exec_opts = [
  "--workspace-folder",
  ".",
  "--config",
  "$HOME/.config/devcontainer/devcontainer.json",
]

[settings]
default_group = "default"

[settings.devcontainer]
skip_up_if_running = true

[dev_commands]
claude1 = "claude --dangerously-skip-permissions"
claude2 = "CLAUDE_CONFIG_DIR=$HOME/.claude-account2 claude --dangerously-skip-permissions"
codex = "codex --yolo"
```

### 主な設定項目

- `groups.<name>.repos`
  - 管理対象リポジトリの配列です。
- `groups.<name>.base_dir`
  - worktree を作る基準ディレクトリです。相対パスの場合は先頭 repo から解決します。
- `groups.<name>.worktree_prefix`
  - task root のディレクトリ名 prefix です。
- `groups.<name>.devcontainer.up_opts` / `exec_opts`
  - `devcontainer up` / `devcontainer exec` にそのまま渡す引数配列です。
- `settings.default_group`
  - `--group` 未指定時のデフォルトです。
- `settings.devcontainer.skip_up_if_running`
  - 既存コンテナが動いているときに `devcontainer up` をスキップするかどうかです。
- `dev_commands`
  - `multi-worktree dev <task>` で引数を省略したときに Go 製の fuzzy picker から選ぶ候補です。

## 使い方

### create

```bash
multi-worktree create feat/add-auth
multi-worktree create feat/add-auth --branch=develop
multi-worktree create feat/add-auth --from=release/2026.03
multi-worktree create feat/add-auth --group=work
```

- `--branch` と `--from` は同じ意味です。
- ベースブランチ未指定時は各 repo のデフォルトブランチを使います。
- task root には synthetic git repository と `.devcontainer/devcontainer.json`, `.claude/settings.local.json` を生成します。

生成される構成の例:

```text
../worktrees/multi-worktree-feat-add-auth/
├── .git/
├── .claude/
├── .devcontainer/
├── repo-a/
└── repo-b/
```

### recreate

```bash
multi-worktree recreate feat/add-auth
multi-worktree recreate feat/add-auth --group=work
```

- 既存 path は保持しつつ、欠けている repo worktree を補充します。
- task root の synthetic git repository と support files は current config で再生成します。

### list

```bash
multi-worktree list
```

出力は TSV 形式です。

```bash
multi-worktree list | awk -F '\t' '{print $1, $3}'
```

### status

```bash
multi-worktree status feat/add-auth
multi-worktree status main
multi-worktree status main --group=work
```

### sync

```bash
multi-worktree sync feat/add-auth
multi-worktree sync feat/add-auth repo-a repo-b
multi-worktree sync feat/add-auth --all
multi-worktree sync feat/add-auth --all repo-a
```

- デフォルトでは task worktree の `HEAD` を main worktree 側に `checkout --detach` します。
- `--all` を付けると `rsync` でファイルも完全同期します。

### cd / open

```bash
multi-worktree cd feat/add-auth
multi-worktree cd feat/add-auth repo-a
multi-worktree open feat/add-auth
```

### dev

```bash
multi-worktree dev feat/add-auth
multi-worktree dev feat/add-auth claude1
multi-worktree dev feat/add-auth -- npm test
```

- 引数なしなら `[dev_commands]` から内蔵の fuzzy picker で選択します。
- `dev_commands` の key を 1 つだけ渡した場合は、その value を `/bin/sh -lc` で実行します。
- それ以外は渡した引数列をそのまま `devcontainer exec` へ流します。

### exec

```bash
multi-worktree exec feat/add-auth -- make test
multi-worktree exec feat/add-auth repo-a -- npm install
multi-worktree exec main repo-a -- git status
multi-worktree exec main --group=work backend -- make build
```

### remove

```bash
multi-worktree remove feat/add-auth
multi-worktree remove feat/add-auth --force
```

- 対話確認ありです。
- `--force` は `git worktree remove` 失敗時にディレクトリ強制削除を試します。

## 検証コマンド

```bash
env -i PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
  GOCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/build" \
  GOPATH="${TMPDIR:-/tmp}/multi-worktree-go-cache/path" \
  GOMODCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/mod" \
  go test ./tools/multi-worktree/...

env -i PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
  GOCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/build" \
  GOPATH="${TMPDIR:-/tmp}/multi-worktree-go-cache/path" \
  GOMODCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/mod" \
  go run ./tools/multi-worktree/cmd/multi-worktree --help
```
