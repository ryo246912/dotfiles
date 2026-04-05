# DOTFILE-24 agent CLI 設定再実装

## 概要

- Linear の既存 workpad では 2026-03-13 時点で実装済み扱いになっているが、今回の `dotfiles` repo copy の `DOTFILE-24` ブランチは `origin/main` と同一で差分がない。
- このため、現行 repo copy 上で ticket scope を再適用し、設定・ドキュメント・PR 作成までやり直す。
- 調査基準日は 2026-04-05 とし、対象は「agent CLI のみ」「公式 repo が直近 1 か月以内に更新されているもの」のみに限定する。

## 要件

### 機能要件

- `mise` で host / devcontainer の両方に agent CLI を導入できるようにする。
- devcontainer から各 CLI の config / data directory を共有できるように mount を追加する。
- 既存の `zabrze` ベースの AI ショートカットに、新規 agent CLI の host / devcontainer 呼び出し導線を追加する。
- 公式に設定ファイル形式が確認できる CLI については、初期設定ファイルを repo 管理下に追加する。
- `agent-cli.md` を追加し、使い方・無料利用可否・学習利用可否・除外理由を日本語で整理する。
- `README.md` と `setup.md` から `agent-cli.md` に辿れるようにする。

### 非機能要件

- API キーや secret は repo に入れず、環境変数やローカル設定に逃がす。
- telemetry / usage statistics を CLI 側で無効化できるものは、無効寄りの初期値を採用する。
- 既存の `gemini` / `opencode` / `codex` / `claude` 設定を壊さずに拡張する。
- `opencode` は既存設定を残しつつ、今回の ticket scope からは除外理由を明記する。

### 制約条件

- 調査は公式 repo / 公式 docs / 公式 privacy 関連ページを優先し、2026-04-05 時点の内容を根拠にする。
- 対象ツールは、2026-03-05 以降に公式 repo の更新があるものに限定する。
- `opencode-ai/opencode` は 2025-09-18 に archive 済みのため、今回の実装対象から外す。

## 実装計画

### 1. 調査スコープの再固定

- 公式 GitHub repo の `pushed_at` を再取得して include / exclude を確定する。
- 無料利用と学習利用可否は「CLI 自体」と「接続先 provider」のどちらに依存するかを切り分ける。
- 現時点の対象は以下とする。
  - 実装対象: `aider`, `cline`, `codebuff`, `crush`, `gemini-cli`, `goose`, `gptme`, `nanocoder`, `neovate`, `qwen-code`
  - 除外: `opencode`

### 2. install / runtime layer の更新

- `dot_config/mise/config.toml` と `dot_config/devcontainer/mise.toml` に対象 CLI を追加する。
- `dot_config/devcontainer/devcontainer.json` に対象 CLI の config / data directory mount を追加する。
- `dot_local/bin/executable_setup-ai-tool` を拡張し、既存 Claude MCP 設定に加えて agent CLI の bootstrap で必要なディレクトリ初期化を行う。

### 3. config / convenience layer の追加

- `dot_aider.conf.yml` を追加し、aider の既定挙動を repo 向けに整える。
- `dot_config/crush/crush.json` を追加し、metrics 無効化・compact UI・context file 優先を設定する。
- `dot_config/goose/config.yaml` を追加し、telemetry 無効化・approval mode・theme などを定義する。
- `dot_config/gptme/config.toml` を追加し、global prompt / MCP / local config 分離前提の土台を作る。
- `dot_config/nanocoder/agents.config.json` を追加し、provider 雛形・session / auto-compact を設定する。
- `dot_qwen/settings.json` を追加し、usage statistics 無効化と session / tool approval 既定値を設定する。
- `dot_config/zabrze/ai.toml` と `dot_config/multi-worktree/config.toml.sample` に各 CLI の起動ショートカットを追加する。

### 4. ドキュメント整備

- `agent-cli.md` に対象 / 除外ツール一覧、インストール方法、config path、無料利用可否、学習利用可否、公式リンクを整理する。
- `README.md` と `setup.md` に agent CLI ガイドへの導線を追加する。
- 必要なら `.chezmoiignore` に repo-only ドキュメントを追加し、home 配下へ apply されないようにする。

## 変更対象ファイル

- `dot_config/mise/config.toml`
- `dot_config/devcontainer/mise.toml`
- `dot_config/devcontainer/devcontainer.json`
- `dot_config/zabrze/ai.toml`
- `dot_config/multi-worktree/config.toml.sample`
- `dot_local/bin/executable_setup-ai-tool`
- `.chezmoiignore`
- `README.md`
- `setup.md`
- `agent-cli.md`
- `dot_aider.conf.yml`
- `dot_config/crush/crush.json`
- `dot_config/goose/config.yaml`
- `dot_config/gptme/config.toml`
- `dot_config/nanocoder/agents.config.json`
- `dot_qwen/settings.json`

## 検証方法

- `git diff --check`
- `taplo format --check dot_config/mise/config.toml dot_config/devcontainer/mise.toml dot_config/multi-worktree/config.toml.sample dot_config/gptme/config.toml`
- `jq empty dot_config/devcontainer/devcontainer.json dot_config/crush/crush.json dot_config/nanocoder/agents.config.json dot_qwen/settings.json`
- `ruby -e 'require \"yaml\"; YAML.load_file(\"dot_aider.conf.yml\"); YAML.load_file(\"dot_config/goose/config.yaml\")'`
- `sh -n dot_local/bin/executable_setup-ai-tool`
- `shellcheck dot_local/bin/executable_setup-ai-tool`

## リスクと未解決事項

- `goose` の `mise` backend は GitHub release / `ubi` 前提で追加するため、実インストール時に asset 名との差異が出る可能性がある。
- `codebuff` / `neovate` / `gptme` は「学習に使われない」ことを公式に明言したページを確認しづらく、provider 依存または未明示として整理する可能性がある。
- `cline` / `neovate` は設定の多くが interactive UI / internal state 側に寄っているため、repo 管理できる静的 config は限定的になる。
