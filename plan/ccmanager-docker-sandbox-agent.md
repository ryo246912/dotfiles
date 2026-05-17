# ccmanager Docker Sandboxes 経由 AI Agent 対応

## 概要

- ccmanager の commandPresets に **Docker Sandboxes**（Docker製品、`sbx` CLI）経由で AI Agent を起動するプリセットを追加する
- Docker Sandboxes は使い捨て隔離環境（microVM）で Agent を実行し、ファイルシステム・ネットワークを分離する
- セッションデータはホスト側のディレクトリをマウントすることで永続化できる
- `[settings.sandbox].default_agent` のような設定ファイルの default は**使わない**

## Docker Sandboxes の費用について

**Sandbox 機能自体は無料（追加課金なし）。**

- `sbx` CLI は Docker Desktop に付属（Docker Desktop は無料利用枠あり）
- Sandbox インフラ自体の費用はない
- 課金されるのは各 Agent の API トークン費用のみ（通常の利用と同じ）

## セッションの永続化について

**可能。** `sbx run` はファイルシステムパススルーで動作するため、追加ワークスペースとして渡したディレクトリへの変更はホストに即時反映される。

**仕組み:**
- `sbx run <agent> <dir1> <dir2>` の形で複数ディレクトリをマウントできる
- sandbox 内外で同一絶対パスで見えるため、双方向・即時同期（コピーではない）
- sandbox を削除（`sbx rm`）してもマウントしたディレクトリのファイルはホストに残る

**各 Agent のセッション保存先（devcontainer のマウント設定より）:**

| Agent | セッションデータパス |
|-------|---------------------|
| Claude | `~/.claude` |
| Codex | `~/.codex` |
| Copilot | `~/.local/state/.copilot` |
| Gemini | `~/.gemini` |

**注意:** `~/.claude` のユーザーレベル設定は sandbox 内では読み込まれない。セッションデータ（`.local/share/`以下）とは別物。

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

| 課題 | 対応策 |
|------|--------|
| `sbx` CLI のインストール | Docker Desktop の最新版が必要。`sbx --version` で確認 |
| 各 Agent の実際のセッション保存パス | devcontainer のマウント設定で確認済み（claude: `~/.claude`, codex: `~/.codex`, copilot: `~/.local/state/.copilot`, gemini: `~/.gemini`） |
| ccmanager の状態検出が sandbox 経由で動作するか | `detectionStrategy: "claude"` は出力パターンで検出するため、sandbox 内の出力がそのまま流れてくれば動作するはず。実機で要確認 |
| `sbx run` の引数渡し構文（`--` の位置）| `sbx run <agent> <workspaces...> -- <agent-args...>` が正しい構文か要確認 |
| `~/.claude` 設定が読まれない | MCP サーバー設定等が必要な場合は `.claude/settings.json` に記載が必要 |

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
