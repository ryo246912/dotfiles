# DOTFILE-15 CodeRabbit 設定見直し

## 概要

- CodeRabbit CLI と rulesync 管理下の skill / rule / command を見直し、AI agent がコミットフックに依存せず未コミット差分へ自律レビューを実行できる状態に揃える。
- 既存の `review-fix` と責務が重なる設定は増やさず、CodeRabbit の新しい `code-review` 相当の運用だけを repo に反映する。

## 要件

### 機能要件

- `dot_config/rulesync/.rulesync/skills/coderabbit/SKILL.md` を、公式 `code-review` skill 相当の review loop に合わせる。
- Gemini 用 command と Claude / Codex / Gemini / Copilot 向け rules に、CodeRabbit の未コミット差分レビュー導線を追加する。
- `rulesync 7.23.0` で壊れている Copilot target 設定を修正し、user-scope generate が通る状態に戻す。
- `.coderabbit.yaml` で AI agent 向け prompt を有効化する。
- rulesync README に現在の運用方針と generate / 検証方法を反映する。

### 非機能要件

- 既存の `review-fix` と役割重複を起こさない。
- rulesync source を正本として保ち、generate で再現できる内容にする。
- 日本語主体の instructions / skill と repo 既存の英語ドキュメントを壊さない。

### 制約条件

- 作業はこの repository copy 内だけで完結させる。
- user-scope 実ファイルへの書き込みは行わず、rulesync source と dry-run / generate で検証する。
- PR コメント修正フローは既存 `review-fix` に委譲する。

## 実装計画

### 1. 現行設定の差分整理

- `coderabbit --version` / `coderabbit review --help` / `coderabbit auth status` で CLI 実態を確認する。
- `rulesync generate -c dot_config/rulesync/rulesync.jsonc --dry-run` の失敗理由を確認し、設定不整合を特定する。
- 既存 rules / skills / commands / `.coderabbit.yaml` / README の責務を整理する。

### 2. CodeRabbit review loop の source 反映

- root `.rulesync/rules/CLAUDE.md` に Claude Code 向けの CodeRabbit 実行方針を追加し、repo `CLAUDE.md` を再生成する。
- user-scope の Claude / Codex / Gemini / Copilot rules に、CodeRabbit review loop と `review-fix` 分離方針を追加する。
- `coderabbit` skill と Gemini command を、`coderabbit review --prompt-only --type uncommitted` ベースの 2-pass review loop に更新する。
- `.coderabbit.yaml` の `enable_prompt_for_ai_agents` を有効化する。

### 3. rulesync 運用ドキュメントの更新

- `dot_config/rulesync/rulesync.jsonc` の target を現行 rulesync に合わせて修正する。
- `dot_config/rulesync/README.md` に CodeRabbit / rulesync の現在の運用方針、generate 手順、検証方法をまとめ直す。
- 必要に応じて Copilot / Codex / Gemini の生成先説明を更新する。

### 4. 検証と仕上げ

- `rulesync generate` と `rulesync generate -c dot_config/rulesync/rulesync.jsonc --dry-run` で source の整合性を確認する。
- `coderabbit review --prompt-only --type uncommitted` を実行し、実際に review loop が回ることを確認する。
- `taplo format --check`、`prettier --check`、`git diff --check` を実行して整形・差分エラーを潰す。

## 技術的課題と対応策

- CodeRabbit の新しい公式 skill 名は `code-review` だが、repo には既存の `coderabbit` skill がある。
  - 対応策: skill 名は互換性のため維持しつつ、中身を `code-review` 相当へ更新する。
- 公式 `autofix` skill は `review-fix` と責務が競合する。
  - 対応策: repo には追加せず、README と skill 内で責務分離を明記する。
- rulesync の Copilot target 名がバージョン更新で変わっている。
  - 対応策: target を現行値へ更新し、dry-run で生成先を確認する。

## テスト計画

- `coderabbit --version`
- `coderabbit review --help`
- `coderabbit auth status`
- `(cd dotfiles && rulesync generate)`
- `(cd dotfiles/dot_config/rulesync && rulesync generate -c rulesync.jsonc --dry-run)`
- `(cd dotfiles && coderabbit review --prompt-only --type uncommitted)`
- `(cd dotfiles && taplo format --check)`
- `(cd dotfiles && prettier --check '**/*.{json,yaml,yml}' )`
- `(cd dotfiles && git diff --check)`

## リリース計画

- 設定変更のみのため、merge 後は `chezmoi apply` または user-scope `rulesync generate` でローカル環境へ反映できる。
- user-scope 出力を更新するときは `chezmoi re-add` で source へ取り込む。

## 参考資料

- https://docs.coderabbit.ai/cli/index
- https://zenn.dev/oikon/articles/coderabbit-cli
- https://linear.app/ryoryoryo/issue/DOTFILE-15/coderabbitcliやskillの設定
