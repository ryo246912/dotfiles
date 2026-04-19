# DOTFILE-34 実装結果

## 追加された導線

- `gd` / `gr` / `gi` で定義・参照・実装ジャンプを使える
- `n` / `N` で、検索未開始でもカーソル上単語の次/前へ移動できる
- diagnostics が inline 表示される
- 現在ファイル向けの format / lint / test を picker から実行できる
- 保存時 format を ON / OFF できる

## 主なコマンド

- `:LspEnable` / `:LspDisable` / `:LspToggle`
  - LSP と diagnostics の有効/無効を切り替える
- `:InlineDiagnosticsEnable` / `:InlineDiagnosticsDisable` / `:InlineDiagnosticsToggle`
  - inline diagnostics の表示を切り替える
- `:CurrentFileActions`
  - 現在ファイル向けに解決できた action を picker で選んで実行する
- `:FormatBuffer`
  - 現在バッファを formatter で整形する
- `:SaveHooksEnable` / `:SaveHooksDisable` / `:SaveHooksToggle`
  - 保存時 format hook の ON/OFF を切り替える

## 主なキーマップ

- `gd`
  - 定義ジャンプ
- `gr`
  - 参照一覧
- `gi`
  - 実装ジャンプ
- `K`
  - hover 表示
- `[d` / `]d`
  - diagnostic 前後移動
- `<leader>xi`
  - inline diagnostics を切り替える
- `<leader>xa`
  - current file action picker を開く
- `<leader>xf`
  - 現在バッファを format する
- `<leader>xh`
  - save hook を切り替える
- `n` / `N`
  - 既存検索結果、またはカーソル上単語を起点に次/前へ移動する

## 対応内容

### LSP / jump

- Go: `gopls`
- TypeScript / JavaScript: `ts_ls` 優先、無ければ `tsserver`
- Python: `pyright` 優先、無ければ `basedpyright`
- GraphQL: `graphql`。LSP で取れない場合は `rg` fallback
- Terraform: `terraformls`
- TOML: `taplo`
- そのほか JSON / YAML も server を起動する

### formatter / action

- JavaScript / TypeScript / JSON / YAML / GraphQL: `prettier`
- Python: `ruff format` / `ruff check` / `pytest`
- Go: `gofmt -w` / `go test .` / `golangci-lint run .`
- Terraform: `terraform fmt` / `terraform validate`
- TOML: `taplo format` / `taplo lint`

## 使い方

1. 対象ファイルを開く
2. ジャンプしたい識別子上で `gd` / `gr` / `gi` を使う
3. 現在ファイルの action を実行したい場合は `<leader>xa`
4. 手動 format は `<leader>xf`
5. 保存時 format を止めたい/戻したい場合は `<leader>xh` か `:SaveHooksToggle`
6. inline diagnostics が邪魔なときは `<leader>xi` か `:InlineDiagnosticsToggle`

## 注意点

- `CurrentFileActions` に出る候補は、そのプロジェクトで実際に見つかった binary や script に依存する
- GraphQL の定義/参照は server 実装差を吸収するため、結果によって quickfix を開く場合がある
- headless 環境でも command 登録は通るようにしてあるが、interactive な picker や terminal は通常 UI 起動時に使う想定
