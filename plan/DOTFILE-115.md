# DOTFILE-115 Hermes Agent の使い方と設定の実装

## 目的とスコープ

- `dotfiles` リポジトリ内で Hermes Agent を再利用しやすくするため、初期設定テンプレートと詳細利用ガイドを追加する。
- 今回の主眼は「できるだけ詳細な使い方を Markdown にまとめること」と「安全に再現できる設定の土台を用意すること」。
- 実装対象は `dotfiles` 内のドキュメントと設定ファイルに限定し、秘密情報や外部サービスの実キーはコミットしない。

## 調査結果の要約

- 公式の導入導線は one-line installer か manual install の 2 系統で、Windows ネイティブは非対応、WSL2 利用が前提。
- Hermes の主要設定は `~/.hermes/config.yaml` と `~/.hermes/.env` に集約される。
- 初期利用で重要なコマンドは `hermes`、`hermes --tui`、`hermes model`、`hermes tools`、`hermes setup`、`hermes doctor`、`hermes update`、`hermes gateway setup`。
- 設定・運用で説明価値が高い論点は provider 設定、toolsets、`approvals.mode`、terminal backend、`mcp_servers`、context files（`AGENTS.md` / `CLAUDE.md`）、skills、gateway。
- `dotfiles` 側には `dot_claude/`、`dot_codex/`、`dot_gemini/` は存在するが、Hermes 用の設定・導線はまだ存在しない。
- 詳細な prose を置く場所としては `not_config/memo/` が最も近く、`setup.md` は導線追加先として自然。

## 要件

### 機能要件

- Hermes のベース設定を保存する `dot_hermes/config.yaml` を追加する。
- `not_config/memo/hermes-agent.md` に詳細利用ガイドを追加する。
- `setup.md` から Hermes の導入手順またはガイドへの導線を追加する。
- 利用ガイドには最低限、以下を含める。
  - インストール方法（installer / manual）
  - 初回セットアップ（provider、tools、setup wizard）
  - 基本的な使い方（CLI / TUI / 主要コマンド / slash commands）
  - 設定ファイルの役割（`config.yaml`、`.env`、skills、memories）
  - 実運用で重要な設定（approvals、toolsets、terminal backend、MCP、gateway、context files）
  - 更新・診断・トラブルシュート

### 非機能要件

- ドキュメントは日本語で、公式ドキュメントに基づき、後から読み返して再現できる粒度にする。
- 機密情報はテンプレート化しない。必要なキーはプレースホルダや説明に留める。
- 既存の `dotfiles` 構成と整合するファイル配置にする。

### 制約条件

- 作業はこのリポジトリコピー内に限定する。
- `~/.hermes/.env` のような秘密情報ファイルはコミット対象にしない。
- 公式導線と大きく異なる独自インストール手順は採用しない。

## 実装方針

### 1. Hermes の設定テンプレートを追加する

- `dot_hermes/config.yaml` を新規追加する。
- 内容は「すぐ使える安全な初期値」と「あとから埋める項目の雛形」を両立させる。
- 少なくとも以下を扱う。
  - `approvals.mode` の初期値とコメント
  - terminal backend の切り替え余地
  - `mcp_servers` のサンプル雛形
  - gateway / toolsets / auxiliary model まわりの参照コメント
- API キーは `~/.hermes/.env` 側で設定する前提にして、設定ファイルには埋め込まない。

### 2. 詳細利用ガイドを追加する

- `not_config/memo/hermes-agent.md` を新規追加する。
- 以下の章立てで、公式 docs の用語とコマンドに寄せて整理する。
  - Hermes Agent の概要
  - インストール手順
  - 初回セットアップ
  - 日常利用の基本コマンド
  - 設定ファイルとディレクトリ構成
  - provider / tools / approvals / terminal backend の設定
  - MCP / skills / context files / memory
  - messaging gateway
  - update / doctor / troubleshooting
  - `dotfiles` での運用メモ
- 読者が「インストールして最初の会話を始める」ところから「MCP や gateway を有効化する」ところまで追える構成にする。

### 3. 既存のセットアップ導線を更新する

- `setup.md` に Hermes の項目を追加するか、少なくとも新規ガイドへのリンクを追加する。
- 既存 README から `setup.md` へは導線があるため、まずは `setup.md` 更新を優先し、README 直接更新は必要最小限に留める。

## 変更予定ファイル

- `dot_hermes/config.yaml`
- `not_config/memo/hermes-agent.md`
- `setup.md`

## 検証方法

- 内容確認: `rg -n "hermes|Hermes|approvals|mcp_servers" setup.md not_config/memo/hermes-agent.md dot_hermes/config.yaml`
- YAML 整形確認: `prettier --check dot_hermes/config.yaml`
- 手順整合確認: 公式 docs の Installation / Quickstart / Configuration / Security / MCP / Context Files / Messaging と章立て・コマンドを照合する
- 差分確認: `git diff -- dot_hermes/config.yaml not_config/memo/hermes-agent.md setup.md`

## リスクと未解決事項

- 詳細ガイドの置き場は `not_config/memo/` を想定しているが、実装中に `navi` cheat 形式の補助ファイルも必要と判明した場合は別 issue に切り出す余地がある。
- Hermes の公式導線は installer 中心で、`mise` から直接 CLI を配布する前提ではない。そのため今回のスコープでは `mise` への追加は優先しない。
- `dot_hermes/config.yaml` の雛形は安全側に倒す必要があり、`approvals.mode: off` や過剰な MCP 露出のような設定は採用しない。

## レビュー観点

- `dotfiles` に追加するファイル配置が既存構成に馴染むか
- 利用ガイドの粒度が「詳細」である一方、秘密情報や危険設定を安易に推奨していないか
- 実装スコープが「詳細ドキュメント + 安全な設定土台」に収まっているか
