# DOTFILE-25 主要code agentの改善

## 概要

- Codex / Claude Code / Copilot 向けに、repo 管理できる通知 hook と補助設定を追加する。
- 提供された `dotfiles/` の repo copy には旧 workpad の実装結果が存在しないため、現行 `main` (`b2fa17a`) を基準に再構築する。

## 要件

### 機能要件

- 共通の通知 helper script と、Codex / Copilot 用 wrapper script を追加する。
- Claude Code / CCManager / multi-worktree の通知設定を helper 経由に寄せる。
- Codex 用 `dot_codex/config.toml` を追加し、Codex の通知設定を repo 管理にする。
- Copilot 用 `.github/hooks/*.json` と `.github/copilot-instructions.md` を追加する。
- `dot_config/rulesync/rulesync.jsonc` の Copilot target typo を修正し、temp HOME generate で Codex / Copilot 生成物を検証できる状態にする。
- `setup.md` と関連 README に、主要 code agent 向けの推奨追加設定を理由付きで整理する。

### 非機能要件

- 通知 helper は macOS 以外や通知コマンド未導入環境でも安全に no-op できる。
- devcontainer 内では必要な path / config を mount して、ホスト通知 relay を継続利用できる。
- 既存の Claude / CCManager / multi-worktree 運用を壊さずに移行する。

### 制約条件

- 作業対象は `dotfiles/` 配下に限定する。
- 設定キーや hook schema は 2026-04-05 時点の公式ドキュメントを基準にする。
- 既存の rulesync source、devcontainer、multi-worktree の構成を尊重し、不要な仕組み追加は避ける。

## 実装計画

### 1. 計画と生成元の整合を戻す

- `plan/dotfile-25.md` を復元し、workpad と repo copy の不整合を解消する。
- `dot_config/rulesync/rulesync.jsonc` の `copilotonvs` を `copilot` に修正する。
- temp HOME で `rulesync generate` を実行し、Codex / Copilot の生成先と必要ファイルを確認する。

### 2. 通知 helper と agent 設定を追加する

- `dot_local/bin/executable_ai-agent-notify` を追加し、agent 名・event 名・payload JSON から通知文面を組み立てる。
- `dot_local/bin/executable_ai-agent-notify-codex` と `dot_local/bin/executable_ai-agent-notify-copilot` を追加する。
- `dot_claude/settings.json` に Claude Code の `Notification` / `Stop` hook を追加する。
- `dot_config/ccmanager/config.json` と `dot_local/bin/executable_multi-worktree` を helper 呼び出しへ置き換える。
- `dot_codex/config.toml` を追加し、Codex の `notify` / `tui.notifications` を repo 管理にする。
- `.github/hooks/*.json` と `.github/copilot-instructions.md` を追加する。

### 3. devcontainer / ドキュメント / 検証を完了する

- `dot_config/devcontainer/devcontainer.json` の mount を `~/.local/bin` / `~/.copilot` ベースに更新する。
- `dot_config/rulesync/README.md`、`dot_config/multi-worktree/README.md`、`setup.md` に運用手順と推奨設定を追記する。
- Prettier / taplo / shell syntax / rulesync generate / diff 確認を実行する。
- 変更を commit / push し、draft PR と Linear 更新まで完了する。

## 変更対象ファイル

- `dot_claude/settings.json`
- `dot_config/ccmanager/config.json`
- `dot_config/devcontainer/devcontainer.json`
- `dot_config/multi-worktree/README.md`
- `dot_config/rulesync/README.md`
- `dot_config/rulesync/rulesync.jsonc`
- `dot_local/bin/executable_ai-agent-notify`
- `dot_local/bin/executable_ai-agent-notify-codex`
- `dot_local/bin/executable_ai-agent-notify-copilot`
- `dot_local/bin/executable_multi-worktree`
- `dot_codex/config.toml`
- `dot_codex/AGENTS.md`
- `dot_codex/skills/*`
- `.github/copilot-instructions.md`
- `.github/hooks/*.json`
- `setup.md`

## 技術的課題と対応策

- Copilot の hook schema は CLI と cloud agent で共有されるため、GitHub Docs の `.github/hooks/*.json` 仕様に合わせて実装する。
- Codex の notify payload は将来変わる可能性があるため、helper は `cwd` や event 名が取れない場合でも汎用メッセージへフォールバックする。
- devcontainer 内では Notification Center を直接叩けないため、helper 側で devcontainer 判定時のみ SSH relay を試し、それ以外の非 macOS 環境では no-op にする。

## テスト計画

- temp HOME で `rulesync generate` を実行し、Codex / Copilot の生成物が出ることを確認する。
- `prettier --check` で JSON を確認する。
- `taplo format --check` で `dot_codex/config.toml` を確認する。
- `bash -n` で helper script と `executable_multi-worktree` を確認する。
- `git diff` と `git status --short` で想定範囲の差分だけであることを確認する。

## デプロイ・リリース計画

- `DOTFILE-25` ブランチへ commit して push する。
- `gh pr create --draft --title "DOTFILE-25: 主要code agentの改善"` で draft PR を作成する。
- PR に `symphony` label を付与し、Linear issue へ PR を紐づける。

## 参考資料

- Claude Code settings: `https://docs.anthropic.com/en/docs/claude-code/settings`
- Claude Code hooks: `https://code.claude.com/docs/en/hooks`
- Codex config reference: `https://developers.openai.com/codex/config-reference`
- Codex config docs: `https://github.com/openai/codex/blob/main/docs/config.md`
- GitHub Copilot custom instructions: `https://docs.github.com/en/copilot/how-tos/custom-instructions/adding-repository-custom-instructions-for-github-copilot`
- GitHub Copilot hooks reference: `https://docs.github.com/en/copilot/reference/hooks-configuration`
- 参考記事: `https://note.com/cute_agapan9087/n/nf54c17fc5f43`
