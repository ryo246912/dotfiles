# DOTFILE-34 nvim で VSCode みたいな設定

## 概要

- VSCode 側で使っているコードジャンプ、inline diagnostics、format on save、current file action の導線を Neovim に寄せる。
- 現 repo copy には以前の実装差分が入っていないため、既存設定をベースに VSCode ライクな導線を再構築する。

## 要件

### 機能要件

- Go / TypeScript / Python / GraphQL / Terraform / TOML で定義・参照・実装ジャンプを使えるようにする。
- カーソル上の単語を起点に `n` / `N` で次・前の一致へ移動できるようにする。
- LSP diagnostics を VSCode Error Lens に近い inline 表示にする。
- 現在開いているファイルに対して lint / test / format などの action を選んで実行できるようにする。
- 保存時に format を実行でき、必要に応じて save hook を ON / OFF できるようにする。
- 実装内容と使い方を日本語ドキュメントへまとめる。

### 非機能要件

- 既存 plugin 構成をできるだけ壊さず、Neovim 標準機能と既存 plugin を優先して使う。
- headless Neovim でも command 登録や起動確認ができる状態にする。
- 現在ファイル action は project-local binary や一般的な CLI を優先的に解決し、未知の repo でも壊れにくくする。

### 制約条件

- 作業対象は `/Users/ryo./Programming/ai/DOTFILE-34` 配下のみ。
- 既存 workpad は別 path 前提のため、その差分を前提にせず現 repo copy へ実装し直す。
- `git fetch origin --prune` は `.git/FETCH_HEAD` への書き込みで失敗するため、同期確認は read-only な git 情報で補完する。

## 実装計画

### 1. LSP / diagnostics / navigation の拡張

- `dot_config/nvim/lua/plugins/lsp.lua` を更新し、対象 server を Go / TS / Python / GraphQL / Terraform / TOML / JSON / YAML まで拡張する。
- 共通 `on_attach` に definition / reference / implementation / type definition などのキーマップをまとめる。
- `vim.diagnostic.config` を設定し、inline diagnostics と float 表示を VSCode ライクに整える。

### 2. 現在単語検索と current file action の追加

- `dot_config/nvim/lua/core/keymaps.lua` に `n` / `N` の smart search 初期化を追加し、検索が未開始でも現在単語へジャンプできるようにする。
- `dot_config/nvim/lua/core/file_actions.lua` を新設し、format / lint / test action の解決、terminal 実行、save hook 制御を集約する。
- `dot_config/nvim/lua/plugins/terminal.lua` から current file action picker と関連 command / keymap を公開する。

### 3. ドキュメントと検証

- `02-implement.md` に今回の差分内容と実装意図を整理する。
- `03-result.md` に使い方と主要コマンド / キーマップをまとめる。
- repo-local XDG 環境で headless 起動・command 登録・format/save hook/current file action の smoke test を実施する。

## 技術的課題と対応策

- 以前の実装差分が現 repo copy に存在しない。
  - 現設定を再調査して必要機能を最小構成で再実装する。
- formatter / lint / test コマンドは repo ごとに異なる。
  - project root / package manager / local binary を見て候補を組み立て、見つかった action のみを提示する。
- save 時 formatter は filetype ごとに実装方式が異なる。
  - LSP format を優先し、CLI formatter が必要な filetype では current file action でも同じ解決ロジックを使う。

## テスト計画

- `nvim --headless '+qa'` で plugin load と command 登録を確認する。
- `nvim --headless '+Lazy! sync' '+qa'` で plugin 同期を確認する。
- minimal Neovim harness で `n` / `N`、`CurrentFileActions`、`FormatBuffer`、`SaveHooksToggle` を検証する。
- `git status --short --branch` で差分を確認する。

## リスクと未解決事項

- environment にない formatter / test runner は action 候補へ出せないため、repo ごとの差異は残る。
- `git fetch` の書き込み権限問題が継続する場合、最新 main の取り込み証跡は read-only な git 情報へ依存する。
