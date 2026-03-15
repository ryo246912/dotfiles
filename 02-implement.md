# DOTFILE-34 作業中実装メモ

## 概要

- `DOTFILE-34` は Linear 上ではまだ `Todo` だが、作業ブランチ `DOTFILE-34` には Neovim 設定の途中差分がすでに存在する。
- 今回はその差分内容を再確認し、Plan review 用に「どこまで入っているか」「何が未完了か」を整理した。

## 現在の差分で入っている内容

### 1. LSP / コードジャンプ関連

- `dot_config/nvim/lua/plugins/lsp.lua`
  - `pyright` と `terraformls` を追加
  - GraphQL の対象 filetype を拡張
  - `gd`, `gr`, `gi` などの既存導線に加え、call hierarchy が使える場合は `incoming` / `outgoing` の導線を追加
  - diagnostics の virtual text を Error Lens 風に見えるよう調整
  - インライン diagnostics の ON / OFF 用 command を追加
  - LSP document highlight を有効化

### 2. カーソル単語の `n` / `N`

- `dot_config/nvim/lua/core/keymaps.lua`
  - 既存検索がないときは `<cword>` を `/` レジスタに入れてから `n` / `N` を実行するように変更
  - 追加の検索入力なしで現在単語の次/前へ移動できる

### 3. 現在ファイル向け lint / test / format 実行

- `dot_config/nvim/lua/core/file_actions.lua`
  - 新規追加ファイル
  - filetype と project root をもとに current buffer 用の action を組み立てる
  - JS/TS 系では `prettier`, `eslint`, `vitest` / `jest`
  - Python では `ruff`, `pytest`
  - Go では `gofmt`, `golangci-lint`, `go test`
  - Terraform では `terraform fmt`, `terraform validate`
  - TOML では `taplo format`
- `dot_config/nvim/lua/plugins/terminal.lua`
  - `CurrentFileActions` command を追加
  - `<leader>cf` で現在ファイル向け action picker を開けるようにした
  - 選択した action は floating terminal で実行される

### 4. save hook / format-on-save

- `dot_config/nvim/init.lua`
  - `require("core.file_actions").setup()` を追加
- `dot_config/nvim/lua/core/file_actions.lua`
  - `FormatBuffer`, `SaveHooksEnable`, `SaveHooksDisable`, `SaveHooksToggle` を追加
  - `BufWritePost` で current buffer に format action がある場合に save hook を実行
  - current buffer が modified のまま format action を走らせるケースを考慮して保存前処理を追加
- `dot_config/nvim/lua/core/keymaps.lua`
  - `<leader>uf`: 明示 format
  - `<leader>uh`: save hook toggle

## まだ未完了の内容

- `03-result.md` は未作成
- 代表 filetype での smoke test は未実施
- headless での Neovim 起動検証は未実施
- 実装済み差分が acceptance criteria をすべて満たすかは未確認

## この時点での判断

- main の要求に対する実装はかなり進んでいる
- ただし review なしで続行するより、いったん Plan review として差分を固定化した方が安全
- 以降は `plan/dotfile-34-nvim-vscode-like-settings.md` と Linear の `## Agent Workpad` を正として進める
