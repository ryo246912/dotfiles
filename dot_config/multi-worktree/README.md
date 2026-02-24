# multi-worktree

マルチリポジトリ × git worktree 管理ツール

複数のリポジトリに対して、タスク単位で git worktree を一括作成し、共通の親ディレクトリにまとめて devcontainer でマウントする仕組みを提供します。

## 特徴

- **タスク単位でのマルチリポジトリ管理**: 複数のリポジトリに対して同じブランチ名で worktree を一括作成
- **devcontainer 自動生成**: タスクごとに devcontainer.json を自動生成し、すべてのリポジトリを一括マウント
- **グループ管理**: 用途別にリポジトリをグループ化して管理可能

## インストール

このツールは chezmoi で管理されており、以下のファイルで構成されています：

- `dot_local/bin/executable_multi-worktree` - メインスクリプト
- `dot_config/multi-worktree/config.toml.sample` - 設定ファイルのサンプル
- `dot_config/multi-worktree/completion.bash` - Bash 補完スクリプト
- `dot_config/multi-worktree/_multi-worktree` - Zsh 補完スクリプト

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

## 使い方

### 基本的なワークフロー

1. **タスク用の worktree を一括作成**

```bash
multi-worktree create feat/add-auth
```

これにより、以下のような構造が作成されます：

```
../worktrees/multi-worktree-feat-add-auth/
├── repo-a/                   # repo-a の worktree (ブランチ: feat/add-auth)
├── repo-b/                   # repo-b の worktree (ブランチ: feat/add-auth)
└── .devcontainer/
    └── devcontainer.json     # 自動生成された設定
```

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

3. **worktree ディレクトリに移動**

```bash
multi-worktree cd feat/add-auth
```

新しいシェルが起動し、worktreeディレクトリに移動します。`exit`で元のディレクトリに戻ります。

4. **VSCode で worktree を開く**

```bash
multi-worktree open feat/add-auth
```

worktreeディレクトリをVSCodeで開きます。

5. **devcontainer でコマンドを実行**

```bash
multi-worktree exec feat/add-auth ccmanager
```

devcontainerを起動し、その中でコマンドを実行します。既にコンテナが起動している場合はスキップされます。

6. **各リポジトリのステータスを確認**

```bash
multi-worktree status feat/add-auth
```

7. **作業終了後、worktree を一括削除**

```bash
multi-worktree remove feat/add-auth
```

### グループの指定

デフォルト以外のグループを使用する場合は、`--group` オプションを指定します：

```bash
multi-worktree create feat/new-feature --group=work
multi-worktree list --group=work
multi-worktree remove feat/new-feature --group=work
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

### `list [--group=GROUP]`

作成済みのタスク一覧を表示します。

**例:**
```bash
multi-worktree list
multi-worktree list --group=work
```

### `status <task-name> [--group=GROUP]`

指定したタスクの各リポジトリのステータスを表示します。

**表示内容:**
- ブランチ名
- 変更状況
- 最新のコミット（3件）

**例:**
```bash
multi-worktree status feat/add-auth
```

### `cd <task-name> [--group=GROUP]`

指定したタスクの worktree ディレクトリに移動します。

**動作:**
1. worktree ディレクトリに移動
2. 新しいシェルを起動（`$SHELL`環境変数を使用）
3. `exit` で元のディレクトリに戻る

**例:**
```bash
multi-worktree cd feat/add-auth
# 新しいシェルが起動し、worktree ディレクトリに移動
# 作業後 exit で戻る
exit
```

### `exec <task-name> <command> [args...]`

指定したタスクの devcontainer でコマンドを実行します。

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
multi-worktree exec feat/add-auth ccmanager
multi-worktree exec feat/add-auth bash
multi-worktree exec feat/add-auth npm run dev
```

### `open <task-name> [--group=GROUP]`

指定したタスクの worktree ディレクトリを VSCode で開きます。

**動作:**
1. worktree ディレクトリのパスを解決
2. `code` コマンドを使用して VSCode で開く

**例:**
```bash
multi-worktree open feat/add-auth
multi-worktree open feat/new-feature --group=work
```

**前提条件:**
- VSCode の `code` コマンドがインストールされている必要があります
- VSCode で「Shell Command: Install 'code' command in PATH」を実行済みであること

### `remove <task-name> [--group=GROUP]`

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

このツールは ccmanager の既存パターンと互換性を保っています：

- **単一リポジトリ**: `../worktrees/{project}-{branch}`
- **マルチリポジトリ**: `../worktrees/multi-worktree-{task-name}`

`multi-worktree-` プレフィックスにより、両者を区別できます。

### devcontainer との統合

生成される `devcontainer.json` には以下の設定が含まれます：

- 各リポジトリの worktree をマウント
- 実体リポジトリ（`.git` アクセス用）をマウント
- Git、GitHub CLI、Claude の設定をマウント
- 環境変数 `CCMANAGER_WORKTREE_PATH`, `CCMANAGER_WORKTREE_BRANCH` を設定

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
