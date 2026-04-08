# DOTFILE-22: ai agentのskillsの管理

## 目的とスコープ

- `rulesync` を使って skill source を repo で宣言的に管理し、Claude Code / Codex / Gemini / Copilot 向けの generated output をこの checkout から再現できるようにする。
- 公式の `skill-creator` と review 系 OSS skill を curated source として追加し、ローカル skill (`plan`, `review-fix` など) と共存させる。
- `plan` skill を artifact 指向へ改修し、調査・計画・実装・テストの切り替え条件を明文化する。

## 実装方針

### 1. rulesync source / install / generate の再設計

- `dot_config/rulesync/rulesync.jsonc` に `sources` を追加し、`anthropics/skills` の `skill-creator` と review 系 OSS skill を `rulesync install` で取得できるようにする。
- `dot_config/rulesync/rulesync.lock` を commit し、ref を固定する。
- user-scope generate は temp HOME へ出力してから repo の `dot_claude` / `dot_codex` / `dot_gemini` / `dot_copilot` へ同期する script 化で対応し、`chezmoi re-add` 前提をやめる。

### 2. plan skill / command の改修

- `dot_config/rulesync/.rulesync/skills/plan/SKILL.md` を、`plan/00-search.md` `00-spec.md` `01-plan{-xxx}.md` `02-implement.md` `03-test.md` `99-instrucemt.md` を使う phase-driven workflow に書き換える。
- `/plan` `/plan:implement` `/plan:search` 相当の command source を `dot_config/rulesync/.rulesync/commands/` に追加する。

### 3. ドキュメント・generated output の更新

- `dot_config/rulesync/README.md` と repo root `CLAUDE.md` source を、新しい skill catalog と repo-local generate フローに合わせて更新する。
- rulesync generate の結果として `dot_claude`, `dot_codex`, `dot_gemini`, `dot_copilot`, `CLAUDE.md` を再生成する。

## 変更予定ファイル

- `dot_config/rulesync/rulesync.jsonc`
- `dot_config/rulesync/rulesync.lock`
- `dot_config/rulesync/.gitignore`
- `dot_config/rulesync/scripts/executable_generate-user.sh`
- `dot_config/rulesync/README.md`
- `dot_config/rulesync/.rulesync/skills/plan/SKILL.md`
- `dot_config/rulesync/.rulesync/commands/plan*.md`
- `mise.toml`
- `dot_config/mise/config.toml`
- `.rulesync/rules/CLAUDE.md`
- generated output: `CLAUDE.md`, `dot_claude/**`, `dot_codex/**`, `dot_gemini/**`, `dot_copilot/**`

## 検証方針

- `git fetch origin main` で同期状態を確認する。
- `rulesync install` で curated skill source と lockfile を生成・固定する。
- repo-local generate script で tracked output を更新し、`rulesync generate --dry-run` で source と出力が整合することを確認する。
- `taplo format --check mise.toml dot_config/mise/config.toml` を通す。
- `git diff -- dot_config/rulesync dot_claude dot_codex dot_gemini dot_copilot CLAUDE.md` を確認する。
- `dot_config/devcontainer/devcontainer.json` の bind mount が引き続き `~/.claude` / `~/.codex` を参照することを確認する。

## リスクと未解決点

- `plan:implement` のような colon を含む command source はクロスプラットフォームで制約が出る可能性があるため、rulesync generate 実結果を見て成立性を確認する必要がある。
- curated skill は upstream の更新に依存するため、`rulesync.lock` を commit しても将来更新時の差分確認が必要。
- Codex 向け commands / skills は simulated feature に依存するため、生成物の形が Claude/Gemini と異なる可能性がある。
