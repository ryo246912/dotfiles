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
- `dot_local/bin/executable_devcontainer-host-gateway` - devcontainer からのホスト action を制御する forced-command gateway
- `dot_config/multi-worktree/config.toml.sample` - 設定ファイルのサンプル
- `dot_config/multi-worktree/templates/local-project-AGENTS.md` - local project 用 `AGENTS.md` テンプレート
- `dot_config/multi-worktree/templates/local-project-CLAUDE.md` - local project 用 `CLAUDE.md` テンプレート
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

### devcontainer からホストへの通知設定（macOS のみ）

devcontainer 内から macOS ホストに通知を送る場合、SSH 経由で通知を行います。初回セットアップ時に以下の設定が必要です：

```bash
# 1. dotfiles を反映して gateway / wrapper を配置
chezmoi apply

# 2. devcontainer 専用の SSH 鍵を生成（既に存在する場合はスキップ）
if [ ! -f ~/.ssh/id_docker_devcontainer ]; then
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_docker_devcontainer
fi

# 3. 既存の unrestricted entry を削除し、gateway 固定の restricted entry に置き換える
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys

pubkey="$(cut -d' ' -f2 ~/.ssh/id_docker_devcontainer.pub)"
tmp_authorized_keys="$(mktemp)"
grep -vF "$pubkey" ~/.ssh/authorized_keys > "$tmp_authorized_keys" || true
~/.local/bin/devcontainer-host-gateway authorized-key-entry ~/.ssh/id_docker_devcontainer.pub >> "$tmp_authorized_keys"
cat "$tmp_authorized_keys" > ~/.ssh/authorized_keys
rm -f "$tmp_authorized_keys"

# 4. 権限設定
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_docker_devcontainer

# 5. 確認
ls -la ~/.ssh/id_docker_devcontainer*
grep devcontainer-host-gateway ~/.ssh/authorized_keys
```

**設定後の動作:**
- コンテナ起動時に自動的に SSH 設定が行われます
- Claude Code の hooks（Notification、Stop）が allowlist 経由で macOS の通知センターに表示されます
- 未定義コマンドや raw shell はホストで実行されず、「確認が必要」であることだけが通知されます
- コンテナを再作成しても設定は永続化されます

**注意事項:**
- macOS の「システム設定 > 一般 > 共有 > リモートログイン」が有効になっている必要があります
- `authorized_keys` に同じ公開鍵の unrestricted entry が残っていると bypass できるため、上記手順で必ず置き換えてください
- allowlist に含まれる host action は現在 `notify --event <pending|stop> --worktree <safe-name> --tmux <0|1>` のみです

### local project に生成される AI ガイド

`multi-worktree create <task>` は worktree ルートに以下を生成します。

- `AGENTS.md`
- `CLAUDE.md`
- `.claude/settings.local.json`

これらのファイルには、devcontainer からホストへ送れる action が allowlist 制御されていること、raw shell を直接 SSH しないこと、通知は `~/.config/devcontainer/scripts/devcontainer-host-action.sh` を経由することが明記されます。

### 検証コマンド

ホスト側 gateway の挙動は、通知コマンドを stub に差し替えてローカルでも確認できます。

```bash
stub_dir="$(mktemp -d)"
cat > "${stub_dir}/macos-notify-cli" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${TMPDIR:-/tmp}/devcontainer-host-gateway.log"
EOF
chmod +x "${stub_dir}/macos-notify-cli"

PATH="${stub_dir}:$PATH" \
SSH_ORIGINAL_COMMAND='notify --event pending --worktree sample --tmux 0' \
DEVCONTAINER_HOST_NOTIFY_BIN=macos-notify-cli \
~/.local/bin/devcontainer-host-gateway

PATH="${stub_dir}:$PATH" \
SSH_ORIGINAL_COMMAND='/bin/echo blocked' \
DEVCONTAINER_HOST_NOTIFY_BIN=macos-notify-cli \
~/.local/bin/devcontainer-host-gateway || true

PATH="${stub_dir}:$PATH" \
SSH_ORIGINAL_COMMAND='unknown-action' \
DEVCONTAINER_HOST_NOTIFY_BIN=macos-notify-cli \
~/.local/bin/devcontainer-host-gateway || true
```

devcontainer 側 wrapper の実運用確認は、devcontainer 内で以下を実行します。

```bash
~/.config/devcontainer/scripts/devcontainer-host-action.sh notify --event pending --worktree sample --tmux 0
ssh -F ~/.config/ssh/config mac-host /bin/echo blocked
ssh -F ~/.config/ssh/config mac-host unknown-action
```

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

5. **devcontainer でコマンドを実行**

```bash
multi-worktree exec feat/add-auth ccmanager
```

devcontainerを起動し、その中でコマンドを実行します。既にコンテナが起動している場合はスキップされます。

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

### `dev <task-name> [command]`

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
multi-worktree dev feat/add-auth claude
multi-worktree dev feat/add-auth ccmanager
multi-worktree dev feat/add-auth bash
```

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
