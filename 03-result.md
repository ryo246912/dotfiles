# DOTFILE-34 実装結果

## 概要

Neovim 側の設定を VSCode ライクな操作感へ寄せるために、LSP ナビゲーション、現在単語の `n` / `N` 移動、インライン diagnostics、現在ファイル起点の lint / test / format 実行、save hook による format-on-save を追加した。

## 追加したこと

### 1. LSP とコードジャンプ

- `dot_config/nvim/lua/plugins/lsp.lua`
  - `gopls`, `graphql`, `pyright`, `taplo`, `terraformls`, `ts_ls` / `tsserver` を対象にした設定を追加
  - `gd`, `gD`, `gr`, `gi`, `K`, `<leader>rn`, `<leader>ca`, `[d`, `]d`, `<leader>fd` を LSP attach 時に利用可能
  - call hierarchy を提供する server では `<leader>ci` で incoming calls、`<leader>co` で outgoing calls を開ける
  - document highlight を有効化し、カーソル下シンボルの参照箇所を見やすくした

### 2. `n` / `N` の VSCode ライク導線

- `dot_config/nvim/lua/core/keymaps.lua`
  - 既存の検索語がない状態で `n` / `N` を押したとき、カーソル下の単語を検索対象へ自動設定するように変更
  - 追加の `/` 入力なしで次・前の一致へ移動できる

### 3. Error Lens 風のインライン diagnostics

- diagnostics の `virtual_text` を有効化し、`E` / `W` / `I` / `H` prefix つきでインライン表示
- `<leader>ud` または `:InlineDiagnosticsToggle` で ON / OFF を切り替え可能

### 4. 現在ファイル起点の lint / test / format

- `dot_config/nvim/lua/core/file_actions.lua`
  - filetype と project root から、現在ファイル向けの action を解決する module を追加
  - local bin を最優先し、Node 系は `package.json` に依存が宣言されている場合のみ package runner を使う
  - `.venv` を root marker に含め、Python の project-local tool を拾いやすくした
- `dot_config/nvim/lua/plugins/terminal.lua`
  - `<leader>cf` / `:CurrentFileActions` で current file action picker を開けるようにした
  - 選択した action は floating terminal 上で実行される

対象例:

- JS / TS / GraphQL / JSON / YAML: `prettier`, `eslint`, `vitest` / `jest`
- Python: `ruff`, `pytest`
- Go: `gofmt`, `golangci-lint`, `go test`
- Terraform: `terraform fmt`, `terraform validate`
- TOML: `taplo format`

### 5. format-on-save と save hook 切替

- `dot_config/nvim/init.lua`
  - `core.file_actions.setup()` を初期化時に呼び出すように変更
- `dot_config/nvim/lua/core/file_actions.lua`
  - `FormatBuffer`, `SaveHooksEnable`, `SaveHooksDisable`, `SaveHooksToggle` を追加
  - save 時に format action がある filetype では自動で formatter を実行
- `dot_config/nvim/lua/core/keymaps.lua`
  - `<leader>uf`: 現在ファイルを明示 format
  - `<leader>uh`: save hook の ON / OFF 切替

## 使い方

### コードジャンプ

- 定義へ: `gd`
- 宣言へ: `gD`
- 参照へ: `gr`
- 実装へ: `gi`
- hover: `K`
- rename: `<leader>rn`
- code action: `<leader>ca`
- diagnostics 移動: `[d`, `]d`
- diagnostics 詳細: `<leader>fd`
- 呼び出し元/先: `<leader>ci`, `<leader>co`

### 検索

- カーソル上の単語をそのまま次へ: `n`
- カーソル上の単語をそのまま前へ: `N`

### 現在ファイル action

- picker を開く: `<leader>cf`
- format だけ即実行: `<leader>uf`

### save hook

- save hook 切替: `<leader>uh`
- command で切替: `:SaveHooksToggle`
- command で format: `:FormatBuffer`

## 補足

- Python / Terraform の LSP server 本体が未導入なら、interactive 起動時に Mason から導入される前提
- current file test action はファイル名規約から候補を推定するため、プロジェクトごとに最適化余地はある
- headless 検証で不要な UI plugin (`nvim-notify`, `fzf-lua`) は初期化を抑制し、CI 風の起動確認でこけにくくしている
