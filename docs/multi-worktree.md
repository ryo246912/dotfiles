# multi-worktree

マルチリポジトリ × git worktree 管理ツール

複数のリポジトリに対して、タスク単位で git worktree を一括作成し、共通の親ディレクトリにまとめて Docker Sandboxes（または devcontainer）で扱う仕組みを提供します。

## 特徴

- **タスク単位でのマルチリポジトリ管理**: 複数のリポジトリに対して同じブランチ名で worktree を一括作成
- **Docker Sandboxes 統合**: `multi-worktree dev <task> [agent]` で task root を workspace にした microVM を起動（既定バックエンド）
- **devcontainer 自動生成**: タスクごとに devcontainer.json を自動生成し、すべてのリポジトリを一括マウント（`--devcontainer` 経路）
- **グループ管理**: 用途別にリポジトリをグループ化して管理可能

## インストール

このツールは chezmoi で管理されており、以下のファイルで構成されています：

- `dot_local/bin/executable_multi-worktree` - メインスクリプト
- `dot_config/multi-worktree/config.toml.sample` - 設定ファイルのサンプル
- `dot_config/multi-worktree/completion.bash` - Bash 補完スクリプト
- `dot_config/multi-worktree/_multi-worktree` - Zsh 補完スクリプト
- `docs/docker-sandboxes.md` - Docker Sandboxes の使い方と devcontainer 比較

### 基本セットアップ

chezmoi apply 後、設定ファイルを作成してください：

```bash
# 設定ディレクトリの作成
mkdir -p ~/.config/multi-worktree

# サンプルファイルをコピーして編集
cp ~/.config/multi-worktree/config.toml.sample ~/.config/multi-worktree/config.toml
vim ~/.config/multi-worktree/config.toml
```

### タブ補完の有効化

シェルでタブ補完を使用するには、以下のコマンドを `.zshrc` または `.bashrc` に追加してください：

```bash
# Bash の場合
source ~/.config/multi-worktree/completion.bash

# Zsh の場合
fpath=(~/.config/multi-worktree $fpath)
autoload -Uz compinit && compinit
```

設定後、シェルを再起動するか `source ~/.zshrc` / `source ~/.bashrc` でリロードしてください。

**補完の動作:**

- サブコマンドの補完（`multi-worktree <Tab>` で `create`, `remove`, `list` などを表示）
- タスク名の補完（`multi-worktree remove <Tab>` で既存のタスク名を表示）
- オプションの補完（`--group=` の補完）
- Zsh では各サブコマンドの説明も表示されます

### devcontainer からホストへの通知設定（macOS のみ）

devcontainer 内から macOS ホストへ SSH 経由で通知を送るための初回セットアップが必要です。
この仕組みは `multi-worktree` 固有ではなく、この base template から起動する devcontainer 共通の
ものなので、手順とトラブルシューティングは [docs/devcontainer.md](./devcontainer.md) にまとめています。

## 設定ファイル

`~/.config/multi-worktree/config.toml` の例：

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

[settings]
default_group = "default"

[settings.sandbox]
backend = "sbx"
default_agent = "claude"
name_prefix = "mw"
extra_workspaces = [
  "~/.config/git/config:ro",
  "~/.config/gh:ro",
  "~/.agents",
]
```

### 設定項目

#### `[groups.<グループ名>]`

- `repos`: 管理対象のリポジトリパス（配列）
  - 絶対パスまたは `~` を使った相対パスを指定
- `base_dir`: worktree を作成するベースディレクトリ
  - リポジトリからの相対パスを指定（例: `../worktrees`）
- `worktree_prefix`: worktree ディレクトリ名のプレフィックス
  - 通常は `multi-worktree` を指定

#### `[settings]`

- `default_group`: デフォルトで使用するグループ名

#### `[settings.sandbox]`

- `backend`: `dev` サブコマンドの既定バックエンド（`sbx` | `devcontainer`、デフォルト: `sbx`）
- `default_agent`: `multi-worktree dev <task>` で agent を省略したときのデフォルト
- `name_prefix`: sandbox 名の接頭辞（sandbox 名は `<prefix>-<task>-<agent>`）
- `template`: sandbox template の OCI 参照（省略時は `sbx` の既定 template）
- `extra_workspaces`: task root に加えてマウントする workspace（`:ro` で read-only）

詳細は [docs/docker-sandboxes.md](./docker-sandboxes.md) を参照してください。

## 使い方

### 基本的なワークフロー

1. **タスク用の worktree を一括作成**

```bash
multi-worktree create feat/add-auth
```

これにより、以下のような構造が作成されます：

```
../worktrees/multi-worktree-feat-add-auth/
├── .git/                    # synthetic git repository (ブランチ: multi-worktree-feat/add-auth)
├── .claude/
├── repo-a/                   # repo-a の worktree (ブランチ: feat/add-auth)
├── repo-b/                   # repo-b の worktree (ブランチ: feat/add-auth)
└── .devcontainer/
    └── devcontainer.json     # 自動生成された設定
```

設定を変えたあとや、一部ディレクトリ・設定ファイルだけ欠けたときは、既存 path を壊さず不足分を補充しつつ、task 設定を current config で再生成できます。

```bash
multi-worktree recreate feat/add-auth
```

- 既存の repo worktree directory はそのまま残ります
- まだ存在しない repo worktree だけ current config をもとに追加します
- `.git/` が欠けていれば再作成します
- `.devcontainer/devcontainer.json` と `.claude/settings.local.json` は current config で毎回再生成します

2. **タスク一覧を表示**

```bash
multi-worktree list
```

出力はTSV形式で、awkなどのツールで簡単にパース可能です：

```bash
# タスク名とパスを表示
multi-worktree list | awk '{print $1, $2}'

# パスのみ抽出
multi-worktree list | awk '{print $2}'
```

3. **task root に移動**

```bash
multi-worktree cd feat/add-auth
```

新しいシェルが起動し、task root に移動します。`exit`で元のディレクトリに戻ります。

4. **VSCode で worktree を開く**

```bash
multi-worktree open feat/add-auth
```

worktreeディレクトリをVSCodeで開きます。

5. **Docker Sandboxes でエージェントを起動**

```bash
multi-worktree dev feat/add-auth
multi-worktree dev feat/add-auth claude
```

task root を workspace にした sandbox を作成してアタッチします。devcontainer で実行したい場合は `--devcontainer` を付けます。

```bash
multi-worktree dev feat/add-auth --devcontainer ccmanager
```

7. **各リポジトリのステータスを確認**

```bash
multi-worktree status feat/add-auth
```

8. **作業終了後、worktree を一括削除**

```bash
multi-worktree remove feat/add-auth
```

### グループの指定

デフォルト以外のグループを使用する場合は、`--group` オプションを指定します：

```bash
multi-worktree create feat/new-feature --group=work
multi-worktree list
multi-worktree remove feat/new-feature
```

## コマンドリファレンス

### `create <task-name> [--group=GROUP]`

タスク用の worktree を一括作成します。

- `task-name`: タスク名（そのままブランチ名として使用されます）
  - 例: `feat/add-auth`, `fix/bug-123`, `chore/update-deps`
- `--group=GROUP`: 使用するグループ（省略時はデフォルトグループ）

**動作:**

1. 各リポジトリのデフォルトブランチを fetch
2. 指定されたタスク名でブランチを作成し、worktree を追加
3. タスクディレクトリに `devcontainer.json` を自動生成

**例:**

```bash
multi-worktree create feat/add-auth
multi-worktree create fix/login-bug --group=work
```

### `recreate <task-name> [--group=GROUP]`

既存 task root を壊さず、現在の config をもとに不足している worktree を補充し、task 設定を再生成します。

**動作:**

1. 既存 task があればその group、なければ `--group` またはデフォルト group を使います
2. 各リポジトリについて、存在しない worktree path だけを追加します
3. task root の `.git/` が欠けていれば再作成します
4. `.devcontainer/devcontainer.json` と `.claude/settings.local.json` は current config で上書き再生成します
5. 既存の repo worktree directory はそのまま保持します

**例:**

```bash
multi-worktree recreate feat/add-auth
multi-worktree recreate feat/add-auth --group=work
```

**補足:**

- `recreate` は既存 repo worktree directory を上書きしません
- `devcontainer.json` と `.claude/settings.local.json` は generated file として扱い、`recreate` のたびに current config で更新されます

### `list`

作成済みのタスク一覧を表示します。

**例:**

```bash
multi-worktree list
```

### `status <task-name>`

指定したタスクの各リポジトリのステータスを表示します。

**表示内容:**

- ブランチ名
- 変更状況
- 最新のコミット（3件）

**例:**

```bash
multi-worktree status feat/add-auth
```

### `cd <task-name> [repo]`

指定したタスクの worktree ディレクトリに移動します。

**動作:**

1. worktree ディレクトリに移動
2. 新しいシェルを起動（`$SHELL`環境変数を使用）
3. `exit` で元のディレクトリに戻る

**例:**

```bash
multi-worktree cd feat/add-auth
# 新しいシェルが起動し、worktree ディレクトリに移動
# そのまま task root で ccmanager / ccmc を起動できる
ccmc
# 作業後 exit で戻る
exit
```

### `dev <task-name> [agent] [options] [-- <agent-args...>]`

指定したタスクを Docker Sandboxes backend で起動します（既定バックエンド）。

**動作:**

1. task root を primary workspace として `sbx create --name=<name> <agent> <task-root> <extra-workspaces...>` を実行（同名 sandbox があれば作成をスキップ）
2. 作成直後に agent の設定ディレクトリを指す環境変数（`CLAUDE_CONFIG_DIR` / `CODEX_HOME`）を `/etc/sandbox-persistent.sh` に書き込む
3. `sbx run <name>` でアタッチする
4. `--` 以降は agent CLI にそのまま渡す

**オプション:**

- `--name=NAME`: sandbox 名を明示指定（省略時は `<prefix>-<task>-<agent>`）
- `--branch=BRANCH`: sandbox の branch mode で起動（`auto` で自動命名）
- `--template=REF`: sandbox template の OCI 参照
- `--new`: 既存 sandbox を再利用せず作り直す
- `--devcontainer`: devcontainer backend に切り替える

**設定項目:**

- `[settings.sandbox].backend` / `default_agent` / `name_prefix` / `template` / `extra_workspaces`

**例:**

```bash
multi-worktree dev feat/add-auth                      # 既定 agent を sandbox で起動
multi-worktree dev feat/add-auth claude               # agent を指定
multi-worktree dev feat/add-auth codex -- --continue  # agent に引数を pass-through
multi-worktree dev feat/add-auth claude --branch=auto # branch mode
multi-worktree dev feat/add-auth --new                # sandbox を作り直す
```

### `dev <task-name> --devcontainer [command]`

指定したタスクを devcontainer backend で実行します。

**動作:**

1. worktree ディレクトリに移動
2. コンテナが起動していない場合、`devcontainer up` を実行
3. `devcontainer exec` でコマンドを実行

**設定項目:**

- `[groups.<group>.devcontainer].up_opts`: `devcontainer up` のオプション
- `[groups.<group>.devcontainer].exec_opts`: `devcontainer exec` のオプション
- `[settings.devcontainer].skip_up_if_running`: コンテナ起動済みの場合に `up` をスキップ（デフォルト: true）

**例:**

```bash
multi-worktree dev feat/add-auth --devcontainer claude
multi-worktree dev feat/add-auth --devcontainer ccmanager
multi-worktree dev feat/add-auth --devcontainer bash
```

コマンドを省略すると `[dev_commands]` から fzf で選択できます。

### `exec <task-name> [repo] <command> [args...]`

指定したタスクの task root、または指定リポジトリの worktree でコマンドを直接実行します。

**動作:**

1. task root、または指定したリポジトリの worktree ディレクトリに移動
2. ホスト側でコマンドを直接実行

**例:**

```bash
multi-worktree exec feat/add-auth pwd
multi-worktree exec feat/add-auth repo-a npm run dev
```

### `open <task-name>`

指定したタスクの worktree ディレクトリを VSCode で開きます。

**動作:**

1. worktree ディレクトリのパスを解決
2. `code` コマンドを使用して VSCode で開く

**例:**

```bash
multi-worktree open feat/add-auth
```

**前提条件:**

- VSCode の `code` コマンドがインストールされている必要があります
- VSCode で「Shell Command: Install 'code' command in PATH」を実行済みであること

### `remove <task-name>`

指定したタスクの worktree を一括削除します。

**動作:**

1. 各リポジトリで `git worktree remove` を実行
2. タスクディレクトリを削除

**例:**

```bash
multi-worktree remove feat/add-auth
```

### `help`

ヘルプメッセージを表示します。

```bash
multi-worktree help
```

## ディレクトリ構造

### ccmanager との統合

`multi-worktree create <task>` は task root を synthetic git repository として初期化します。

- task root のブランチ名は `multi-worktree-<task-name>` です
- 配下 repo の worktree ブランチ名は従来どおり `<task-name>` のままです
- task root の `.git/` は `ccmanager` の project discovery 用で、配下 repo の `.git` file とは別物です

#### 単一 task を管理する

```bash
multi-worktree cd feat/add-auth
ccmanager
# または
ccmc
```

`cd` で入る task root が `ccmanager` の project root になります。

#### 同じ group の task を横断管理する

```bash
CCMANAGER_MULTI_PROJECT_ROOT=/path/to/worktrees ccmanager --multi-project
# または
CCMANAGER_MULTI_PROJECT_ROOT=/path/to/worktrees ccmc --multi-project
```

- 起動ディレクトリは任意です
- `CCMANAGER_MULTI_PROJECT_ROOT` には group ごとの `base_dir` を指定します
- multi-project mode では `.ccmanager.json` は使われず、global config のみ使われます

たとえば次の設定なら:

```toml
[groups.default]
repos = [
  "~/dev/repo-a",
  "~/dev/repo-b",
]
base_dir = "../worktrees"
worktree_prefix = "multi-worktree"
```

`base_dir = "../worktrees"` は最初の repo (`~/dev/repo-a`) からの相対パスとして解決されるので、実際の multi-project root は `~/dev/worktrees` です。

```bash
CCMANAGER_MULTI_PROJECT_ROOT=~/dev/worktrees ccmanager --multi-project
```

このコマンドは `~/dev/repo-a` や `~/dev/repo-b` の中で実行する必要はなく、任意のディレクトリから起動できます。

### devcontainer との統合

生成される `devcontainer.json` には以下の設定が含まれます：

- 各リポジトリの worktree をマウント
- 実体リポジトリ（`.git` アクセス用）をマウント
- Git、GitHub CLI、Claude の設定をマウント
- 環境変数 `CCMANAGER_WORKTREE_PATH`, `CCMANAGER_WORKTREE_BRANCH` を設定

### Docker Sandboxes との統合

- `multi-worktree dev <task> [agent]` で task root をそのまま sandbox の primary workspace に渡します
- sandbox 名は `<prefix>-<task>-<agent>`。同名 sandbox があれば再利用（`--new` で作り直し）します
- `[settings.sandbox].extra_workspaces` と agent の設定ディレクトリを追加 workspace としてマウントします
- sbx はホストと同じ絶対パスにマウントするため、agent には `CLAUDE_CONFIG_DIR` / `CODEX_HOME` で設定ディレクトリを明示します
- `.claude/settings.local.json` の通知 hook は `mac-host` が無い環境では no-op になるため、sandbox でも安全側で使えます
- 詳細は [docs/docker-sandboxes.md](./docker-sandboxes.md) を参照してください

## トラブルシューティング

### 設定ファイルが見つからない

```bash
mkdir -p ~/.config/multi-worktree
cp ~/.config/multi-worktree/config.toml.sample ~/.config/multi-worktree/config.toml
```

### ブランチ名が既に存在する

同じタスク名で worktree を作成しようとすると、ブランチ名の競合が発生します。
一度削除してから再作成してください：

```bash
multi-worktree remove feat/add-auth
multi-worktree create feat/add-auth
```

### 設定変更後に不足分だけ補充したい

たとえば group の `repos` に新しいリポジトリを追加したあと、既存 task にその repo の worktree だけ増やしたい場合は `recreate` を使います。

```bash
multi-worktree recreate feat/add-auth
```

`recreate` は既存の repo worktree directory は保持したまま、`devcontainer.json` と `.claude/settings.local.json` を current config で上書き再生成します。`.git/` は欠けているときだけ補修されます。

### Docker Sandboxes CLI が見つからない

`multi-worktree dev <task>` が「sbx コマンドが見つかりません」で失敗する場合は `brew install docker/tap/sbx` でインストールし、`sbx login` でサインインしてください。sandbox を使わず従来どおり devcontainer で動かす場合は `multi-worktree dev <task> --devcontainer <command>` を使うか、`[settings.sandbox].backend` を `"devcontainer"` にします。

### worktree の削除に失敗する

手動で削除する場合は、各リポジトリで以下を実行：

```bash
cd ~/dev/repo-a
git worktree remove ../worktrees/multi-worktree-feat-add-auth/repo-a --force
```

## 関連ツール

- `git-worktree-manager`: 単一リポジトリ内の worktree 対話操作ツール
- `devc-up-wrapper`: devcontainer 起動ラッパー

## ライセンス

このツールは個人の dotfiles リポジトリの一部です。
