# ccmanager Docker Sandboxes 経由 AI Agent 対応

> [!NOTE]
> このプランは実装済みです。実際の使い方は [docs/docker-sandboxes.md](../docs/docker-sandboxes.md) を参照してください。
> 調査時点の想定と実際の `sbx` CLI の仕様が違っていた箇所は、本ドキュメント内で修正しています。

## 概要

- ccmanager の commandPresets に **Docker Sandboxes**（Docker製品、`sbx` CLI）経由で AI Agent を起動するプリセットを追加する
- Docker Sandboxes は使い捨て隔離環境（microVM）で Agent を実行し、ファイルシステム・ネットワークを分離する
- セッションデータはホスト側のディレクトリをマウントすることで永続化できる
- `[settings.sandbox].default_agent` のような設定ファイルの default は**使わない**

## Docker Sandboxes の費用について

**Sandbox 機能自体は無料（追加課金なし）。**

- `sbx` は単体 CLI で、**Docker Desktop は不要**（macOS は `brew install docker/tap/sbx`、Windows は `winget install -h Docker.sbx`）
- 利用には Docker ID でのサインイン（`sbx login`）が必要
- Sandbox インフラ自体の費用はない
- 課金されるのは各 Agent の API トークン費用のみ（通常の利用と同じ）

## セッションの永続化について

**可能。** `sbx run` はファイルシステムパススルーで動作するため、追加ワークスペースとして渡したディレクトリへの変更はホストに即時反映される。

**仕組み:**
- `sbx run <agent> <dir1> <dir2>` の形で複数ディレクトリをマウントできる
- sandbox 内外で同一絶対パスで見えるため、双方向・即時同期（コピーではない）
- sandbox を削除（`sbx rm`）してもマウントしたディレクトリのファイルはホストに残る

**各 Agent のセッション保存先（devcontainer のマウント設定より）:**

| Agent   | セッションデータパス |
| ------- | -------------------- |
| Claude  | `~/.claude`          |
| Codex   | `~/.codex`           |
| Copilot | `~/.copilot`         |
| Gemini  | `~/.gemini`          |

**注意:** sbx はホストと同じ絶対パスに workspace をマウントするため、sandbox 内の `$HOME` はホストとは別物になる。
マウントしただけでは agent が `~/.claude` を見つけられないので、`CLAUDE_CONFIG_DIR` / `CODEX_HOME` を
`/etc/sandbox-persistent.sh` に書き込んで明示する。

## 要件

### 機能要件

- ccmanager から Docker Sandbox 経由の AI Agent セッションを起動できる（claude, codex, copilot, gemini）
- sandbox 内での変更・セッションがホスト側に保存される
- `[settings.sandbox].default_agent` のような default 設定は使わない
- ccmanager の状態検出（idle / waiting_input）が正常に動作する

### 非機能要件

- 既存の commandPresets（claude, gemini, codex 等）の起動フローを壊さない
- Docker Desktop（`sbx` CLI）がインストール済みであることを前提とする

### 制約条件

- ccmanager の config は `dot_config/ccmanager/config.json`（chezmoi 管理）
- ユーザーの XDG_DATA_HOME は `~/.local/share`

## 実装計画

### 1. ラッパースクリプトの作成

`sbx run` の引数にホームディレクトリパスを含めるため、シェルスクリプトでラップする。
JSON の `args` では `~` が展開されないため、スクリプト経由で渡す。

**場所:** `dot_local/bin/sbx-agent`

```bash
#!/usr/bin/env bash
# sbx-agent <agent> [agent-args...]
# Usage: sbx-agent claude
#        sbx-agent codex resume --yolo
AGENT="$1"
shift

# Agent ごとのセッションデータパスを解決
case "$AGENT" in
  claude)   SESSION_DIR="${HOME}/.claude" ;;
  codex)    SESSION_DIR="${HOME}/.codex" ;;
  copilot)  SESSION_DIR="${HOME}/.local/state/.copilot" ;;
  gemini)   SESSION_DIR="${HOME}/.gemini" ;;
  *)        SESSION_DIR="" ;;
esac

if [ -n "$SESSION_DIR" ]; then
  exec sbx run "$AGENT" "$SESSION_DIR" -- "$@"
else
  exec sbx run "$AGENT" -- "$@"
fi
```

セッションデータディレクトリをマウントすることでホスト側に永続化される。

### 2. ccmanager config.json へのプリセット追加

`dot_config/ccmanager/config.json` の `commandPresets.presets` に以下を追加：

```json
{
  "id": "sbx",
  "name": "Claude (Docker Sandbox)",
  "command": "sbx-agent",
  "args": ["claude"],
  "fallbackArgs": ["claude"],
  "detectionStrategy": "claude"
},
{
  "id": "sbx-codex",
  "name": "Codex (Docker Sandbox)",
  "command": "sbx-agent",
  "args": ["codex", "resume", "--yolo"],
  "fallbackArgs": ["codex", "--yolo"],
  "detectionStrategy": "codex"
},
{
  "id": "sbx-copilot",
  "name": "Copilot (Docker Sandbox)",
  "command": "sbx-agent",
  "args": ["copilot", "--resume", "--yolo"],
  "fallbackArgs": ["copilot", "--yolo"],
  "detectionStrategy": "github-copilot"
},
{
  "id": "sbx-gemini",
  "name": "Gemini (Docker Sandbox)",
  "command": "sbx-agent",
  "args": ["gemini", "-s"],
  "fallbackArgs": ["gemini"],
  "detectionStrategy": "gemini"
}
```

### 3. セッションデータディレクトリの事前作成

マウント先が存在しないと `sbx run` がエラーになる可能性があるため、初回セットアップ時に作成：

```bash
mkdir -p ~/.claude
mkdir -p ~/.codex
mkdir -p ~/.local/state/.copilot
mkdir -p ~/.gemini
```

## 技術的課題と対応策

| 課題                                            | 対応策                                                                                                                                   |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `sbx` CLI のインストール                        | Docker Desktop の最新版が必要。`sbx --version` で確認                                                                                    |
| 各 Agent の実際のセッション保存パス             | devcontainer のマウント設定で確認済み（claude: `~/.claude`, codex: `~/.codex`, copilot: `~/.local/state/.copilot`, gemini: `~/.gemini`） |
| ccmanager の状態検出が sandbox 経由で動作するか | `detectionStrategy: "claude"` は出力パターンで検出するため、sandbox 内の出力がそのまま流れてくれば動作するはず。実機で要確認             |
| `sbx run` の引数渡し構文（`--` の位置）         | `sbx run <agent> <workspaces...> -- <agent-args...>` が正しい構文か要確認                                                                |
| `~/.claude` 設定が読まれない                    | MCP サーバー設定等が必要な場合は `.claude/settings.json` に記載が必要                                                                    |

## テスト計画

- [ ] `sbx-agent claude` を単体で実行し sandbox 内で claude が起動することを確認
- [ ] セッション終了後、`~/.local/share/claude/` にデータが保存されていることを確認
- [ ] ccmanager から各 sandbox プリセットを選択し、セッションが正常に立ち上がることを確認
- [ ] ccmanager の状態検出（idle / waiting_input）が正常に動作することを確認

## デプロイ・リリース計画

1. `dot_local/bin/sbx-agent` を作成（実行権限付与）
2. `dot_config/ccmanager/config.json` を編集してプリセット追加
3. セッションデータディレクトリを事前作成
4. `chezmoi diff` で差分確認
5. `chezmoi apply` でデプロイ
6. ccmanager を再起動してプリセット確認
7. 動作確認後コミット

## 参考資料

- [sbx run コマンドリファレンス](https://docs.docker.com/reference/cli/sbx/run/)
- [Docker Sandboxes Usage](https://docs.docker.com/ai/sandboxes/usage/)
- [Docker Sandboxes Architecture](https://docs.docker.com/ai/sandboxes/architecture/)
- `dot_config/ccmanager/config.json` - 既存プリセット設定
- `dot_local/bin/` - 既存カスタムスクリプト群

## 実装結果（調査時点との差分）

| 調査時点の想定                                   | 実際の仕様 / 実装                                                                            |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `sbx` は Docker Desktop 付属                     | 単体 CLI。Docker Desktop 不要（`brew install docker/tap/sbx`）                               |
| `sbx run <agent> <dirs...> -- <args>` で毎回起動 | workspace は**作成時にしか指定できない**ため `sbx create` → `sbx run <name>` に分離          |
| `--name` は `sbx run --name <name>`              | `--name=<name>` 形式。既存 sandbox には `sbx run <name>` でアタッチ（agent 名は渡さない）    |
| `docker sandbox` への fallback                   | 現行製品の CLI は `sbx` のみのため fallback は削除                                           |
| `~/.claude` をマウントすれば読まれる             | sandbox 内の `$HOME` が別物のため `CLAUDE_CONFIG_DIR` / `CODEX_HOME` の明示が必要            |
| ccmanager からのみ利用                           | `multi-worktree dev` の既定バックエンドも sandbox に変更（devcontainer は `--devcontainer`） |

成果物:

- `dot_local/bin/executable_sbx-agent` - `sbx` ラッパー（ccmanager プリセットから呼ばれる）
- `dot_local/bin/executable_multi-worktree` - `dev` サブコマンドの sandbox backend
- `dot_config/ccmanager/config.json` - `sbx` / `sbx-codex` / `sbx-copilot` / `sbx-gemini` プリセット
- `dot_config/multi-worktree/config.toml.sample` - `[settings.sandbox]`
- `docs/docker-sandboxes.md` - 使い方と devcontainer 比較
