# DOTFILE-33 ツール検討・セットアップ計画

## 概要

- 対象は `skills-desktop`、`rudel`、`SkillDeck`、`nono`、`cr-house`、`feature-dev` の 6 件です。
- この issue では、repo 内だけで完結するセットアップ手順と、日本語の利用ガイドを整備します。
- `skills-desktop` / `rudel` / `SkillDeck` / `nono` は調査結果と導入方針の整理が主目的で、`cr-house` / `feature-dev` はこの repo で実際に試せる状態まで持っていく方針です。

## 要件

### 機能要件

- 6 件それぞれについて、用途、対応 OS、導入方法、基本的な使い方、repo との相性を日本語で整理する。
- `nono` については、capability ベース sandbox、OS カーネル強制、危険コマンド遮断、secret 注入、ephemeral/rollback 系の考え方まで説明する。
- `cr-house` は repo-local な Claude skill として配置し、`.coderabbit.yaml` 作成用途の試用手順をまとめる。
- `feature-dev` は repo-local な Claude plugin として配置し、`/feature-dev` の起動方法とワークフローをまとめる。
- 既存の `chezmoi` / `rulesync` / `mise` / Homebrew ベースの管理方針に合わせて、どこまで自動化し、どこから手順書に寄せるかを明確にする。

### 非機能要件

- 作業はこの repository 配下だけで完結させ、外部パスへの設定反映は行わない。
- 既存の設定管理方針を壊さず、user-scope の共有資産と project-local の試用資産を分離する。
- 追加する Markdown は日本語で記述し、既存ファイルのフォーマット規約に従う。
- 実装前に、どの検証が sandbox 制約で通せるかを明文化する。

### 制約条件

- `git pull --ff-only origin main` は、worktree 実体が sandbox 外の `.git/worktrees/...` を参照するため、この session では失敗します。
- `claude --version` など `mise` shim を経由するコマンドは、repo root の `mise.toml` が未 trust のため現状そのままでは失敗します。
- `skills-desktop` や `SkillDeck` のような GUI ツールは、repo 内へ設定を置けても実インストール自体は OS 依存です。自動化できない場合は手順書化で扱います。
- `cr-house` は GitHub README の直接取得が不安定だったため、公開記事と repo 情報を突き合わせながら導入形を確認します。

## 実装計画

### 1. 導入対象ごとの配置方針を決める

- 既存の AI 関連資産の配置先である `dot_claude/`, `dot_config/claude/`, `dot_config/rulesync/.rulesync/skills/`, `dot_local/bin/` を確認し、今回の対象を user-scope と project-local に分ける。
- project-local 試用対象の `cr-house` / `feature-dev` は repo root の `.claude/` 配下へ配置する方針で整理する。
- インストール管理が必要なツールは、`dot_config/mise/config.toml`、`dot_config/brew/brew_cask.json`、`run_once_install-packages_mac.sh` のどれで扱うかを決める。

### 2. `cr-house` と `feature-dev` を repo-local で試せる形にする

- `.claude/plugins/feature-dev/` に upstream plugin 構成を取り込み、repo 内から `claude plugin validate` を試せる前提を整える。
- project-local からすぐ試せるように、`feature-dev` の command / agent を `.claude/commands/` と `.claude/agents/` にも展開する。
- `.claude/skills/coderabbit-config/` に `cr-house` の skill を配置し、`.coderabbit.yaml` 生成の試行手順を整備する。
- 必要なら `README.md` や setup ドキュメントから新規ドキュメントへの導線を追加する。

### 3. 日本語ドキュメントを整備する

- 新規ドキュメントを追加し、6 件を一覧比較できる表と、各ツールのセットアップ手順・用途・基本操作をまとめる。
- `skills-desktop` / `SkillDeck` は GUI skill 管理ツールとしての位置付け、`rudel` は Claude Code セッション分析、`nono` は agent sandbox、`cr-house` / `feature-dev` は Claude 拡張として整理する。
- `nono` では、Landlock / Seatbelt による OS レベル制御、危険コマンドブロック、secret 注入、ephemeral mode の意味を、repo での利用イメージ付きでまとめる。
- `cr-house` と `feature-dev` は、この repo での実行例と試用結果の記録欄を用意する。

### 4. 検証と記録を行う

- 追加ファイルの存在確認、設定ファイルのフォーマット確認、可能であれば `claude` 系コマンドの妥当性確認を行う。
- `mise` trust 制約で `claude` 実行がブロックされる場合は、repo 外を書き換えずに実施できる代替確認手段を優先し、無理なものは blocker ではなく制約として記録する。
- 実装後の workpad には、変更内容、実行した検証、通らなかった検証とその理由を整理して残す。

## 変更対象ファイル

- `plan/DOTFILE-33.md`
- `README.md`
- `docs/ai-agent-tools.md`
- `.claude/plugins/feature-dev/**`
- `.claude/commands/feature-dev.md`
- `.claude/agents/*.md`
- `.claude/skills/coderabbit-config/**`
- `run_once_install-packages_mac.sh`

## 技術的課題と対応策

- `claude` 検証コマンドが `mise` trust に依存している
  - repo 外を書き換えない代替実行方法を優先し、どうしても不可なら validation の制約として明記する。
- upstream 資産の配置形式が repo の運用と一致しない可能性がある
  - まず upstream 構成を崩さず `.claude/` へ取り込み、必要最小限の repo 向け補足だけを追加する。
- GUI ツールの完全自動インストールは環境差分が大きい
  - install 自動化は package manager で安全に扱える範囲に限定し、それ以外は手順書化に寄せる。
- `nono` は sandbox ツールのため、説明が抽象的になりやすい
  - Claude Code を `nono run --profile claude-code -- claude` で包む具体例を中心にまとめる。

## テスト計画

- `test -f ./.claude/skills/coderabbit-config/SKILL.md`
- `test -f ./.claude/plugins/feature-dev/README.md`
- `claude plugin validate ./.claude/plugins/feature-dev`
- `taplo format --check dot_config/mise/config.toml`
- `prettier --check 'docs/**/*.md' './.claude/**/*.md' './.claude/**/*.json' 'dot_config/brew/*.json'`

## リスクと未解決事項

- `skills-desktop` の配布形式次第では、repo で管理できるのは導入手順までになる可能性があります。
- `cr-house` の upstream 取得方法が shell では取りづらいため、実装時に repo 構成の確認が追加で必要になる可能性があります。
- `Human Review(Plan)` 承認後に upstream 構成差分が見つかった場合は、plan を更新してから実装に進みます。

## 参考資料

- `https://github.com/Harries/skills-desktop`
- `https://github.com/obsessiondb/rudel`
- `https://github.com/crossoverJie/SkillDeck`
- `https://github.com/always-further/nono`
- `https://github.com/goofmint/cr-house`
- `https://github.com/anthropics/claude-code/tree/main/plugins/feature-dev`
