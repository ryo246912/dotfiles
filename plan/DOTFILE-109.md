# DOTFILE-109 ルールの自動追記システム

## 概要

- 前回の Copilot 向け実装案を、最新レビュー指示に合わせて Claude / Codex / Gemini 向けへ載せ替える。
- `origin/main` では rulesync 正本が `dot_config/rulesync/exact_dot_rulesync/` に再編されているため、旧構成前提の hook 実装をそのまま残さず再配置する。
- shared runner は 1 本に保ちつつ、native hook を持つ Claude / Codex と、native hook を確認できない Gemini で役割を切り分ける。

## 調査結果

### 現行リポジトリ

- 対象 repo は [`dotfiles`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles)。
- `origin/main` (`83cd7b0`) では user-scope の rulesync 正本が [`dot_config/rulesync/exact_dot_rulesync/`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/exact_dot_rulesync) に移っており、`rulesync.jsonc` は `claudecode` / `codexcli` / `geminicli` / `copilot` / `copilotcli` の `rules` / `skills` / `commands` / `mcp` を feature 単位で制御する。
- 旧実装案が追加していた [`.github/hooks/ai-rule-hook.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/.github/hooks/ai-rule-hook.json) は最新レビュー対象外で、current branch では rebase 時に不要差分として浮いている。
- devcontainer は [`dot_config/devcontainer/devcontainer.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/devcontainer.json) で `~/.config/devcontainer/scripts` と `~/.config/rulesync` を mount できるため、shared runner と prompt source をそのままコンテナ内から参照できる。

### 外部仕様

- Claude Code 公式 docs では `SessionEnd` の `reason` に `clear` があり、`PreCompact` は `manual` / `auto` を判別できる。
- Codex 公式 docs では hooks は `~/.codex/hooks.json` で管理し、`[features].codex_hooks = true` が必要。`UserPromptSubmit` / `Stop` は使えるが、`/clear` 専用 event は公開 docs 上では確認できない。
- Gemini CLI 公式 docs では `~/.gemini/settings.json`、`GEMINI.md`、custom commands、extensions は確認できる一方、session lifecycle hook や `/clear` 前 hook は確認できない。

## 目的とスコープ

### 目的

- ルール提案の自動導線を、最新の dotfiles / rulesync 構成に沿って Claude / Codex で維持する。
- Gemini については現行公式仕様で可能な範囲を rulesync 配下に寄せ、unsupported な自動化部分は明示する。

### スコープ

- `origin/main` への rebase と競合解消
- shared runner の再配置と Copilot 分岐の削除
- Claude / Codex hooks の復元
- Gemini 向け rulesync 管理の fallback 導線追加
- rulesync 配下の説明 / plan / workpad 更新

### スコープ外

- Gemini CLI に存在しない native hook 機能の独自実装
- rulesync 本体への機能追加
- Copilot 向け hook の再導入

## 要件

### 機能要件

- shared runner 1 本で Claude / Codex の hook payload を正規化し、rulesync 正本を参照して提案プロンプトを組み立てられること。
- Claude は `SessionEnd` / `PreCompact` から shared runner を呼び出せること。
- Codex は `hooks.json` と `config.toml` の feature flag で shared runner を呼び出せること。
- Gemini は現行 docs に存在する仕組みだけを使い、rulesync 配下に fallback 導線を置いたうえで limitation を明文化すること。
- rulesync 配下に prompt / command / 説明の正本を置き、tracked hook 設定との差分責務を明示すること。

### 非機能要件

- 無限再帰防止と safe no-op を維持すること。
- devcontainer 内でも同じ path で shared runner と prompt source を読めること。
- 既存の upstream rulesync 再編と矛盾しない配置にすること。

### 制約条件

- 変更対象はこの repository copy のみ。
- native hook が確認できない Gemini では、完全な `/clear` 直前自動実行は保証できない。
- rebase 後の最新 main を基準に検証する。

## 実装方針

### 1. 最新 main へ載せ替える

- `origin/main` を rebase し、旧 `dot_config/rulesync/.rulesync` 前提の差分を `exact_dot_rulesync` 前提へ読み替える。
- Copilot 向け file は今回のスコープから外し、不要な差分を消す。

### 2. shared runner を Claude / Codex 向けに再整理する

- [`dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/scripts/executable_ai-rule-hook.sh) を shared runner として維持する。
- prompt source は [`dot_config/rulesync/hooks/ai-rule-hook.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/hooks/ai-rule-hook.md) に置き、rulesync root から読ませる。
- tool 分岐は Claude / Codex を主対象に整理し、不要になった Copilot 分岐を除去する。

### 3. 各ツールの設定を見直す

- [`dot_claude/settings.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_claude/settings.json) に `SessionEnd` / `PreCompact` hook を復元する。
- [`dot_codex/config.toml`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/config.toml) と [`dot_codex/hooks.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/hooks.json) を復元する。
- Gemini については native hook が見当たらないため、rulesync source 側に manual fallback command を追加し、[`dot_gemini/settings.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_gemini/settings.json) は現行 upstream 設定を尊重したまま説明を補う。

### 4. rulesync 周辺の責務を明文化する

- [`dot_config/rulesync/README.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/README.md) を reintroduce し、`exact_dot_rulesync` と `hooks/` の責務、Gemini limitation、tracked hook files の位置づけを記述する。
- Gemini fallback 用 command source を [`dot_config/rulesync/exact_dot_rulesync/commands/`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/exact_dot_rulesync/commands) に追加する。

## 変更予定ファイル

- 更新: [`dot_claude/settings.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_claude/settings.json)
- 新規: [`dot_codex/config.toml`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/config.toml)
- 新規: [`dot_codex/hooks.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_codex/hooks.json)
- 更新: [`dot_config/devcontainer/devcontainer.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/devcontainer.json)
- 新規: [`dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/devcontainer/scripts/executable_ai-rule-hook.sh)
- 新規: [`dot_config/rulesync/hooks/ai-rule-hook.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/hooks/ai-rule-hook.md)
- 新規: [`dot_config/rulesync/exact_dot_rulesync/commands/ai-rule-hook.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/exact_dot_rulesync/commands/ai-rule-hook.md)
- 新規: [`dot_config/rulesync/README.md`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/dot_config/rulesync/README.md)
- 削除: [`.github/hooks/ai-rule-hook.json`](/Users/ryo./Programming/ai/DOTFILE-109/dotfiles/.github/hooks/ai-rule-hook.json)

## 検証方法

- `git -C /Users/ryo./Programming/ai/DOTFILE-109/dotfiles diff --check`
- `bash -n dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`
- `shellcheck dot_config/devcontainer/scripts/executable_ai-rule-hook.sh`
- `prettier --check '**/*.json'`
- `taplo format --check`
- `AI_RULE_HOOK_DRY_RUN=1 <shared-runner> --tool claude`
- `AI_RULE_HOOK_DRY_RUN=1 <shared-runner> --tool codex`
- `rg -n 'ai-rule-hook|SessionEnd|PreCompact|UserPromptSubmit|codex_hooks|geminicli' dot_claude dot_codex dot_gemini dot_config/devcontainer dot_config/rulesync`

## リスクと未解決事項

- Gemini CLI に native hook がないという前提は、公式 docs からの消極的確認に基づく。docs 追加が後追いで存在する可能性はあるため、README に「現時点では未確認」と明記する。
- Codex の `/clear` 直前 hook は公開 docs 上で確認できないため、`UserPromptSubmit(prompt=/clear)` と `Stop` 補完の組み合わせに留まる。
- rulesync は hooks 自体を generate しないため、hook 設定ファイルは引き続き tracked file として別管理になる。
