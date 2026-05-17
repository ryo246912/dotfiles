# DOTFILE-34 実装メモ

## 概要

Neovim の既存設定に対して、VSCode で日常的に使う導線を寄せるための差分を追加した。今回の主眼は以下の 5 点。

- LSP の定義/参照/実装ジャンプを Go / TypeScript / Python / GraphQL / Terraform / TOML 周辺まで広げる
- 現在カーソル上の単語を起点に `n` / `N` で移動できるようにする
- diagnostics を inline 表示して VSCode Error Lens に近い見え方へ寄せる
- 現在ファイル単位で format / lint / test を選んで実行できるようにする
- 保存時 format を hook 化し、必要に応じて ON / OFF できるようにする

## 変更したファイル

### `dot_config/nvim/lua/plugins/lsp.lua`

- `gopls` / `graphql` / `jsonls` / `taplo` / `terraformls` / `yamlls` / TypeScript server を `mason-lspconfig` で管理するようにした
- Python は `pyright` を優先し、存在しない環境では `basedpyright` に fallback するようにした
- `ruff` が利用可能な環境では formatter/linter 用 client として attach できるようにした
- `gd` / `gr` / `gi` などの LSP keymap を buffer 単位で統一した
- TypeScript では `_typescript.goToSourceDefinition` を優先し、実装側へ飛びやすくした
- GraphQL では LSP で解決できない場合に `rg --vimgrep` を使った定義/参照検索へ fallback するようにした
- `vim.diagnostic.config` を調整し、severity 付きの inline diagnostics を `virtual_text` で表示するようにした
- `LspEnable|Disable|Toggle` と `InlineDiagnosticsEnable|Disable|Toggle` を追加した

### `dot_config/nvim/lua/core/file_actions.lua`

- 新規追加
- 現在バッファの filetype・project root・利用可能 binary を見て formatter / lint / test action を解決する
- formatter は project-local binary を優先し、なければ Mason 管理 binary、最後に PATH 上の binary を試す
- JavaScript/TypeScript 系は `prettier`、Python は `ruff format`、TOML は `taplo format`、Terraform は `terraform fmt`、Go は `gofmt -w` を優先する
- formatter が CLI の場合と LSP の場合で実行経路を分け、どちらでも `FormatBuffer` から使えるようにした
- `CurrentFileActions` で action picker を開き、toggleterm の floating terminal で lint/test を流せるようにした
- `SaveHooksEnable|Disable|Toggle` と `BufWritePre` / `BufWritePost` hook を追加し、保存時 format を切り替えられるようにした

### `dot_config/nvim/lua/plugins/terminal.lua`

- `toggleterm.nvim` 初期化後に `require("core.file_actions").setup()` を呼ぶようにした

### `dot_config/nvim/lua/core/keymaps.lua`

- 検索が始まっていない状態でも、カーソル上単語を検索レジスタへ積んで `n` / `N` で移動できるようにした

### `dot_config/nvim/lua/plugins/util.lua`

- headless 検証時に `nvim-notify` が UI 前提で失敗しないよう、UI が無い場合は setup をスキップするようにした

## 実装上の判断

- 既存 plugin 構成を大きく崩さないため、追加 plugin には依存せず Neovim 標準機能と既存 plugin の組み合わせで実装した
- file action はリポジトリごとの違いが大きいため、固定コマンドではなく「その場で解決できた action だけを出す」設計にした
- GraphQL は server 実装差でジャンプが不安定になりやすいため、LSP が空応答でも `rg` による fallback で導線を残した
- save hook は LSP format と CLI format で発火タイミングを分け、保存ループが起きにくいようにした

## 検証メモ

- repo-local XDG 配下で `nvim --headless '+qa'` を実行し、起動確認を取った
- `CurrentFileActions` / `FormatBuffer` / `SaveHooksToggle` / `InlineDiagnosticsToggle` / `LspToggle` の command 登録を headless で確認した
- TypeScript / Python / Go / Terraform / GraphQL について、言語ごとの smoke harness でジャンプ導線を確認した
- 一時的に作成した検証ファイルと harness は削除済み
