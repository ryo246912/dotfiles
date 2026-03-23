# DOTFILE-45 codereviewツールのカスタマイズ

## 概要

- 無料枠で利用できる範囲を前提に、Gemini Code Assist と CodeRabbit のレビュー挙動をリポジトリ管理でカスタマイズする。
- 対象は GitHub 上の PR レビュー体験と、ローカルの Gemini Code Assist agent mode 利用設定。
- 目的は次の 3 点:
  - Gemini Code Assist のレビューを日本語化し、repo 特性に沿った観点に寄せる
  - Gemini Code Assist の agent mode を有効化し、既存の `dot_gemini/settings.json` と VS Code 設定に統合する
  - CodeRabbit の PR 要約を「変更内容概要 / 変更理由 / 確認した項目」の 3 セクション中心に整理し、不要ノイズを減らす

## 要件

### 機能要件

- repo ルートの `.gemini/` で Gemini Code Assist on GitHub の `styleguide.md` と `config.yaml` を管理する。
- `styleguide.md` で Gemini のレビューコメント、サマリー、概要を日本語で出力させる。
- `config.yaml` で PR オープン時レビュー挙動、コメント量、無視パスなどを設定し、無料枠でもノイズが増えすぎないようにする。
- `dot_gemini/settings.json` で Gemini CLI / VS Code agent mode に必要な Preview Features を有効化する。
- `dot_config/vscode/settings.json` で `geminicodeassist.agentYoloMode` を有効化する。
- repo ルートの `.coderabbit.yaml` で CodeRabbit の言語、要約フォーマット、レビュー出力ノイズ、レビュー対象パスを制御する。
- CodeRabbit の PR 要約は以下のみを主に出力させる:
  - 変更内容概要
  - 変更理由
  - 確認した項目
- 上記以外の有用設定として、不要な poem / fortune / changed files summary などのノイズを抑制する。

### 非機能要件

- chezmoi 管理対象のホームディレクトリ設定と、repo 固有の GitHub 連携設定を混同しない。
- 有料プラン前提の挙動に依存しない。現在の公式設定リファレンスに存在する項目のみを使い、仮に無料枠で一部無視されても安全に degrade する構成にする。
- 既存の `dot_gemini/settings.json` の OAuth / UI / privacy / MCP 設定を壊さない。
- 既存の `dot_config/vscode/settings.json` のフォーマット方針とコメントスタイルを維持する。

### 制約条件

- 作業対象はこの repository copy のみ。
- shell からの `git fetch origin main` は、worktree の git 管理領域が sandbox 外にあるため失敗している。
- plan 承認前のため、この段階では実装に入らない。

## 実装計画

### 1. Gemini Code Assist の GitHub レビュー設定を追加する

- repo ルートに `.gemini/styleguide.md` を追加する。
- `styleguide.md` には次を含める:
  - コメント・サマリーは日本語
  - 根拠ベースで簡潔に指摘する
  - dotfiles / chezmoi repo 特有の観点を含める
  - 生成物や巨大設定データへの過剰な指摘を避ける
  - クロスプラットフォーム配慮、破壊的コマンド回避、保守性重視
- repo ルートに `.gemini/config.yaml` を追加する。
- `config.yaml` の候補値:
  - `have_fun: false`
  - `code_review.comment_severity_threshold: MEDIUM`
  - `code_review.max_review_comments: 20`
  - `code_review.pull_request_opened.help: false`
  - `code_review.pull_request_opened.summary: true`
  - `code_review.pull_request_opened.code_review: true`
  - `code_review.pull_request_opened.include_drafts: false`
  - `ignore_patterns` に review ノイズになりやすいパスを設定
- `ignore_patterns` 候補:
  - `not_config/**`
  - `dot_config/sidebery/**`
  - `dot_config/dbeaver/**`
  - `dot_config/raycast/**`

### 2. Gemini Code Assist の agent mode 関連設定を既存 dotfiles に統合する

- `dot_gemini/settings.json` に `general.previewFeatures: true` を追加する。
- 既存の `mcpServers`、`security.auth`、`privacy`、`ui` は維持する。
- `dot_config/vscode/settings.json` に `geminicodeassist.agentYoloMode: true` を追加する。
- これにより、公式ドキュメントにある agent mode / yolo mode 設定を repo 管理に載せる。
- agent mode の自動承認は安全性トレードオフがあるため、他設定は最小限に留める。今回のスコープでは `coreTools` / `excludeTools` までは広げない。

### 3. CodeRabbit の PR 要約と walkthrough ノイズを調整する

- repo ルートに `.coderabbit.yaml` を追加する。
- 設定候補:
  - `enable_free_tier: true`
  - `language: "ja"`
  - `tone_instructions` で簡潔・事実ベースの口調を指定
  - `reviews.profile: "chill"`
  - `reviews.high_level_summary: true`
  - `reviews.high_level_summary_instructions` で 3 セクションのみを要求
  - `reviews.high_level_summary_in_walkthrough: false`
  - `reviews.poem: false`
  - `reviews.in_progress_fortune: false`
  - `reviews.changed_files_summary: false`
  - `reviews.sequence_diagrams: false`
  - `reviews.estimate_code_review_effort: false`
  - `reviews.related_issues: false`
  - `reviews.related_prs: false`
  - `reviews.suggested_reviewers: false`
  - `reviews.enable_prompt_for_ai_agents: false`
  - `reviews.auto_review.enabled: true`
  - `reviews.auto_review.drafts: false`
  - `reviews.path_filters` に Gemini と同系統の除外パターンを設定
- `high_level_summary_instructions` では、ファイル単位の変更一覧を避け、意図が読み取りづらい場合だけ補足説明を入れるよう指定する。

### 4. 変更後の妥当性確認を行う

- 変更差分が対象ファイルに限定されていることを確認する。
- YAML と JSONC の構造が壊れていないことを確認する。
- 設定値が無料枠前提の意図と矛盾していないことを確認する。
- 計画承認後の実装では、レビュー対象から外すパスが過剰でないことも再確認する。

## 変更対象ファイル

- `/Users/ryo./Programming/ai/DOTFILE-45/.gemini/styleguide.md`
- `/Users/ryo./Programming/ai/DOTFILE-45/.gemini/config.yaml`
- `/Users/ryo./Programming/ai/DOTFILE-45/.coderabbit.yaml`
- `/Users/ryo./Programming/ai/DOTFILE-45/dot_gemini/settings.json`
- `/Users/ryo./Programming/ai/DOTFILE-45/dot_config/vscode/settings.json`

## 検証方法

- `git status --short --branch`
- `git diff -- .gemini .coderabbit.yaml dot_gemini/settings.json dot_config/vscode/settings.json`
- `yamllint .gemini/config.yaml .coderabbit.yaml`
- 目視確認:
  - `.gemini/styleguide.md` が日本語レビュー方針と repo 固有観点を含むこと
  - `.coderabbit.yaml` の要約指示が 3 セクションに限定されていること
  - `dot_gemini/settings.json` に Preview Features が追加され、既存設定が保持されていること
  - `dot_config/vscode/settings.json` に agent yolo mode が既存 JSONC 形式を壊さず追加されていること

## リスクと未解決事項

- CodeRabbit の `high_level_summary_instructions` は現在の公式設定リファレンスには存在するが、過去 changelog では beta / Pro-tier 言及がある。現時点では実装しても安全な設定として扱い、無料枠で無視される場合はデフォルト要約にフォールバックする前提で進める。
- `include_drafts: false` や `path_filters` / `ignore_patterns` の調整が強すぎると、必要なレビューまで抑制する可能性がある。実装時は除外対象を明らかなノイズパスに限定する。
- `geminicodeassist.agentYoloMode` は trusted workspace で全自動承認になるため安全性とのトレードオフがあるが、今回の ticket 要件では有効化を優先する。
- `git fetch origin main` は sandbox 制約で失敗しており、実装フェーズでも同じ制約が続く可能性がある。

## 参考資料

- Google for Developers: https://developers.google.com/gemini-code-assist/docs/customize-gemini-behavior-github
- Google for Developers: https://developers.google.com/gemini-code-assist/docs/use-agentic-chat-pair-programmer
- Google for Developers: https://developers.google.com/gemini-code-assist/docs/gemini-3
- CodeRabbit Docs: https://docs.coderabbit.ai/reference/configuration
- 参考記事: https://zenn.dev/mochiokoneru/articles/gemini-code-assist-review-in-japanese
- 参考記事: https://zenn.dev/google_cloud_jp/articles/8911c960113904
- 参考記事: https://zenn.dev/watakarinto/articles/54e04958419a34
