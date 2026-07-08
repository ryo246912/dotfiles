# DOTFILE-27 pr-create skill 追加

## 概要

- `dot_config/rulesync/.rulesync/skills/` に `pr-create` を追加し、shared skill source として PR 作成 workflow を定義する。
- 対象は source 追加と検証・PR 公開までで、Gemini 向け `commands/` 追加は今回のスコープ外とする。

## 要件

### 機能要件

- GitHub リポジトリごとに push と draft PR 作成まで進められること。
- PR 本文は repo 内の PR template を探索して尊重しつつ、diff を根拠に `変更内容概要` `実装理由` `確認項目` を構築できること。
- 自明な変更は冗長に書かず、全体把握が難しい変更だけ文章で補足する方針を明記すること。
- preflight、template 不在時の fallback、既存 PR 検出、label 付与までの手順を含むこと。

### 非機能要件

- 既存 shared skill と同じ frontmatter 形式で、`claudecode` / `codexcli` の両 target に対応すること。
- repo 固有実装に寄り過ぎず、複数リポジトリで再利用しやすい手順にすること。
- まずは `SKILL.md` 単体で完結し、helper script は必要になった時だけ追加すること。

### 制約条件

- 正本は `dot_config/rulesync/.rulesync/skills/` であり、`commands/` は Gemini 向けなので変更対象に含めない。
- このセッションでは repo copy のみを触り、他パスの chezmoi/worktree には依存しない。
- 現行 branch は `DOTFILE-27`、base は `origin/main` を前提にする。

## 実装方針

### 1. 現状確認と前提整理

- `dotfiles` を作業対象に固定し、`origin/main` 同期、`gh` 認証、既存 PR 不在、PR template 不在を確認する。
- Linear workpad とローカル plan を今の repo copy に合わせて更新する。

### 2. `pr-create` skill の追加

- `dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md` を新規作成する。
- 内容は以下の順で構成する。
  - preflight: branch、差分、upstream、default branch、`gh` 可用性の確認
  - PR template 探索: 標準パスとディレクトリ型 template を探索
  - PR 本文構築: diff・commit・検証結果から `変更内容概要` `実装理由` `確認項目` を組み立てる
  - 文章ルール: 自明な変更は省略し、非自明な意図や全体像だけ補足する
  - publish: push、既存 PR 検出、`gh pr create` / `gh pr edit`、label 付与
  - fallback: template 不在、PR 既存、upstream 未設定、差分不足時の扱い

### 3. 検証と公開

- source が追加されたことを `rg` と `find` で確認する。
- `gh pr create --help` などで依存 CLI の前提を再確認する。
- 差分を確認して commit、push、draft PR 作成、`symphony` label 付与、Linear への PR URL 連携まで行う。

## 変更対象ファイル

- `dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md`
- `plan/DOTFILE-27.md`

## 検証方法

- `git fetch origin main`
- `git rev-list --left-right --count HEAD...origin/main`
- `gh auth status`
- `gh pr create --help`
- `find . -maxdepth 4 \( -path './.github/pull_request_template.md' -o -path './.github/PULL_REQUEST_TEMPLATE.md' -o -path './docs/pull_request_template.md' -o -path './docs/PULL_REQUEST_TEMPLATE.md' -o -path './pull_request_template.md' -o -path './PULL_REQUEST_TEMPLATE.md' -o -path './.github/PULL_REQUEST_TEMPLATE/*.md' \) | sort`
- `rg -n "name: pr-create|description:|targets:" dot_config/rulesync/.rulesync/skills/pr-create/SKILL.md`
- `git diff --stat`

## リスク・未解決事項

- リポジトリによって PR template の配置が異なるため、探索順と fallback の記述が不足すると再利用性が落ちる。
- この repo では generated output を直接持っていないため、source-only で十分かどうかは rulesync 運用前提に依存する。
- `pr-createコマンド` という wording と実体の shared skill のズレは残るが、repo 規約上は skill 実装が正しい。
