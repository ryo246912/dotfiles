# DOTFILE-85 RTK 導入計画

## 概要

- `rtk-ai/rtk` をこの dotfiles repo に取り込み、`Claude Code` / `Codex` / `Gemini CLI` / `GitHub Copilot` の 4 系統で一貫して使える状態を作る。
- 既存の `chezmoi` + `rulesync` 運用を壊さず、設定ファイルと agent 向け instruction を repo 内で再現可能に管理する。
- 利用手順は専用の Markdown にまとめ、導入方法・生成方法・検証方法・ツールごとの差異を 1 か所で確認できるようにする。

## 目的とスコープ

### 目的

- AI ツールの shell 実行結果を `rtk` 経由に寄せ、トークン消費を抑えつつ既存の dotfiles 運用に組み込む。
- repo にある agent 設定の source-of-truth を明確化し、将来の更新でも再生成しやすい構造にする。

### スコープ

- `rtk` 本体の導入経路を `mise` 管理に追加する。
- 4 ツール向けの hook / settings / instruction ファイルを repo 管理下に揃える。
- `rulesync` source と generated output の責務を整理し、repo 内だけで差分確認できる手順を用意する。
- 利用ガイドを新規 Markdown として追加する。

### スコープ外

- 実ユーザー環境の `~/.claude` / `~/.codex` / `~/.gemini` / `~/.github` への直接反映。
- Cursor / Windsurf / Cline / OpenCode など、今回の要求に含まれない agent への展開。

## 要件

### 機能要件

- `dot_config/mise/config.toml` から `rtk` をインストールできること。
- `Claude Code` 向けに、RTK の利用方針と既存ルールを両立した instruction / hook 設定を repo 管理下に置くこと。
- `Codex` 向けに、`AGENTS.md` と `RTK.md` 相当の構成を repo 管理下に置くこと。
- `Gemini CLI` 向けに、`settings.json` と hook script、および instruction を repo 管理下に置くこと。
- `GitHub Copilot` 向けに、hook JSON と `copilot-instructions.md` を repo 管理下に置くこと。
- 導入方法・利用方法・制約事項をまとめた Markdown を追加すること。

### 非機能要件

- 既存の privacy / permissions / MCP 設定を不必要に壊さないこと。
- source file と generated file の責務を明示し、再生成可能性を保つこと。
- 実装中も repo 外へ書き出さず、この repository copy だけで完結させること。

### 制約条件

- この repo は `chezmoi` source なので、反映先ではなく source file を編集する。
- user-scope の instruction は `dot_config/rulesync/.rulesync/rules/*.md` が正本である。
- `dot_config/rulesync/README.md` にある通常の `rulesync generate` / `chezmoi re-add` フローは real home を触るため、そのままは使わない。
- `rulesync 7.23.0` の Copilot target は `copilotonvs` ではなく `copilot` であり、生成先も `~/.github` ではなく `~/.copilot/copilot-instructions.md` になる。
- 公式 README 上、`GitHub Copilot CLI` は `updatedInput` 非対応のため transparent rewrite ではなく deny-with-suggestion になる。
- 公式 README 上、`Codex` は hook ではなく `AGENTS.md` + `RTK.md` による instruction ベースの統合である。

## 現状整理

- `dot_claude/settings.json` と `dot_gemini/settings.json` は既に repo 管理下にあるが、RTK 用 hook は未設定。
- `dot_config/rulesync/.rulesync/rules/CLAUDE.md` / `CODEX.md` / `GEMINI.md` / `COPILOT.md` は存在するが、中身は最小限で RTK 連携の記述がない。
- `dot_codex/`、`.github/copilot-instructions.md`、`.github/hooks/rtk-rewrite.json`、`dot_gemini/hooks/` はまだ存在しない。
- `mise` では `github:rtk-ai/rtk` backend の版一覧取得は可能で、`aqua:rtk-ai/rtk` は registry 未登録だった。
- `rulesync 7.23.0` の current config には廃止済み target `copilotonvs` が残っており、このままでは `rulesync generate` が失敗する。

## 実装アプローチ

### 1. RTK 本体の導入

- `dot_config/mise/config.toml` に `github:rtk-ai/rtk` を追加する。
- 既存のツール追加パターンに合わせて version pin する。
- 利用ガイドにも `mise install` 前提の導線を追加する。

### 2. 公式生成物を repo 内で再現するための staging 方針を作る

- repo 内に一時的な fake HOME を作り、`HOME` をその staging に向けて `rtk init -g`, `rtk init -g --gemini`, `rtk init -g --codex`, `rtk init -g --copilot` を実行する。
- staging 配下の `.claude`, `.codex`, `.gemini`, `.github`, `.config/rulesync` を repo の `dot_claude`, `dot_codex`, `dot_gemini`, `.github`, `dot_config/rulesync` に向ける。
- こうして real home を触らずに、RTK が生成する canonical な設定を確認する。

### 3. rulesync source と generated output を統合する

- instruction の正本は `dot_config/rulesync/.rulesync/rules/` に寄せる。
- `Claude` / `Gemini` の generated instruction は rulesync source を更新してから repo 内 staging で再生成する。
- `Claude` は `RTK.md` と hook script を official generator に合わせて別ファイルで持ち、`CLAUDE.md` 側から `@RTK.md` を参照する。
- `Codex` は `AGENTS.md` を rulesync source から生成しつつ、`RTK.md` は別ファイルとして `dot_codex/RTK.md` を追加する。
- `Copilot` は rulesync source を残しつつ、repo で使う `.github/copilot-instructions.md` は RTK 公式 layout に合わせて別途同期する。
- 既存の「必ず日本語で回答」など repo 独自ルールを RTK 文言と統合し、上書きではなく併存させる。

### 4. ツール別設定を反映する

- `Claude Code`
  - `dot_claude/settings.json` に RTK hook 設定を反映する。
  - `dot_claude/hooks/rtk-rewrite.sh` と `dot_claude/RTK.md` を追加する。
  - `dot_claude/CLAUDE.md` は rulesync generate 結果で更新する。
- `Codex`
  - `dot_codex/AGENTS.md` を rulesync generate 結果で追加する。
  - `dot_codex/RTK.md` を追加し、`AGENTS.md` から参照させる。
- `Gemini CLI`
  - `dot_gemini/settings.json` に BeforeTool hook を反映する。
  - `dot_gemini/hooks/rtk-hook-gemini.sh` を追加する。
  - `dot_gemini/GEMINI.md` は rulesync generate 結果で更新する。
- `GitHub Copilot`
  - `.github/hooks/rtk-rewrite.json` を追加する。
  - `.github/copilot-instructions.md` は RTK 公式の `.github` layout に合わせて追加する。
  - 利用ガイドで VS Code Copilot と Copilot CLI の挙動差を明記する。

### 5. 利用ガイドを追加する

- `docs/rtk.md` を新規追加し、以下をまとめる。
- 導入目的と対象ツール
- `mise` での導入手順
- repo 内 staging を使った生成・更新手順
- 各ツールの設定ファイル対応表
- 動作確認コマンド
- 既知の制約 (`Copilot CLI` の制限、`Codex` は instruction ベース、Claude の built-in tools は hook を通らない点など)
- 必要なら `README.md` からリンクを張る。

## 変更対象ファイル

- 更新
  - `dot_config/mise/config.toml`
  - `dot_config/rulesync/rulesync.jsonc`
  - `dot_config/rulesync/README.md`
  - `dot_config/rulesync/.rulesync/rules/CLAUDE.md`
  - `dot_config/rulesync/.rulesync/rules/CODEX.md`
  - `dot_config/rulesync/.rulesync/rules/GEMINI.md`
  - `dot_config/rulesync/.rulesync/rules/COPILOT.md`
  - `dot_claude/settings.json`
  - `dot_gemini/settings.json`
  - `README.md`（必要ならリンク追加のみ）
- 追加
  - `dot_claude/hooks/rtk-rewrite.sh`
  - `dot_claude/RTK.md`
  - `dot_codex/AGENTS.md`
  - `dot_codex/RTK.md`
  - `dot_gemini/hooks/rtk-hook-gemini.sh`
  - `.github/hooks/rtk-rewrite.json`
  - `.github/copilot-instructions.md`
  - `dot_claude/CLAUDE.md`
  - `dot_gemini/GEMINI.md`
  - `docs/rtk.md`

## 検証方法

### 調査・再現

- `git status --short && git branch --show-current && git rev-parse --short HEAD`
- `git fetch origin main --prune`
- `git merge-base --is-ancestor origin/main HEAD`
- 公式 README の対象箇所を見て、4 ツールの対応方式と生成物を照合する。

### 実装後の確認

- `MISE_TRUSTED_CONFIG_PATHS=$PWD mise ls-remote github:rtk-ai/rtk`
- `taplo format --check dot_config/mise/config.toml`
- `prettier --check dot_claude/settings.json dot_gemini/settings.json .github/copilot-instructions.md`
- repo 内 fake HOME で `rtk init` 系を実行し、hook script / hook JSON / settings patch shape が official generator と一致することを確認する。
- repo 内 fake HOME で `rulesync generate -t claudecode,codexcli,geminicli -f rules` を実行し、generated rule file が repo に反映されることを確認する。
- 生成後に `git diff -- dot_config/rulesync dot_claude dot_codex dot_gemini .github docs README.md` を確認する。
- 利用ガイドに記載した確認コマンドが、各ツールの設定内容と矛盾しないことを確認する。

## リスクと対応策

- `rulesync` の通常運用は real home へ書くため、このタスクの制約と衝突する。
  - 対応: repo 内 fake HOME / symlink staging を使い、生成先を repo に限定する。
- RTK 公式生成物と既存 repo ルールの両方を維持する必要がある。
  - 対応: 生成結果をそのまま採用するのではなく、rulesync source に吸収できる instruction は source 側へ寄せる。
- `rulesync` の Copilot target と RTK 公式の `.github` layout がずれている。
  - 対応: `rulesync` 側は source-of-truth として残しつつ、repo では `.github/copilot-instructions.md` を別途同期する。
- `Copilot CLI` は transparent rewrite ではない。
  - 対応: ガイドに VS Code Copilot と CLI の差を分けて記載する。
- `dot_codex` が未導入のため、chezmoi 上の新規ディレクトリ追加が必要になる。
  - 対応: ignore 設定を確認しつつ、repo 管理対象として明示的に追加する。

## オープンクエスチョン

- `README.md` にリンクだけ追加するか、`setup.md` にも要約を載せるかは実装時の差分量を見て最小構成で判断する。
