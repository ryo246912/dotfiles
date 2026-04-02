# DOTFILE-87 nvim の画像表示・貼り付け設定

## 概要

- Docswell の参考スライドをもとに、Neovim で画像を表示する `folke/snacks.nvim` と、クリップボード画像を貼り付ける `HakonHarnes/img-clip.nvim` を dotfiles に組み込む。
- 対象範囲は Neovim plugin 設定と macOS 用の依存コマンド導入導線までとし、terminal 自体の大きな設定変更や OS への実インストールはこのチケットの範囲外とする。

## 要件

### 機能要件

- Neovim の lazy.nvim 構成に `snacks.nvim` を追加し、`image` 機能を有効化する。
- Markdown など画像参照が発生するバッファで、`snacks.nvim` による画像表示が可能な状態にする。
- `img-clip.nvim` を追加し、Neovim からクリップボード画像をファイル保存して文書へ貼り付けられるようにする。
- 貼り付け画像の保存先は repo 非依存で扱いやすい相対パスを採用し、画像表示側でも探索しやすい構成にする。
- macOS で `img-clip.nvim` を使うために必要な `pngpaste` の導入経路を dotfiles に含める。

### 非機能要件

- 既存の `lazy.nvim` plugin 分割方針と大きく乖離しない構成にする。
- 既存キーマップと衝突しないこと。特に `<leader>p` / `<leader>P` は既存の fzf 系操作に使われているため再利用しない。
- terminal の制約差分があるため、期待値を明示した検証項目を残す。

### 制約条件

- 作業対象はこの repository 内に限定する。
- 既存の Markdown 表示 plugin (`render-markdown.nvim`) を前提に、責務が重ならないように追加設定する。
- `snacks.nvim` の画像表示は terminal capability に依存する。公式 docs では Ghostty は inline 表示対応、WezTerm は inline 非対応で制限付き。
- `snacks.nvim` は PNG 以外の変換で ImageMagick を必要とするため、このチケットでは `img-clip.nvim` が生成する PNG ベースの流れを最低保証とする。

## 実装方針

### 1. Neovim plugin 構成を整理する

- `dot_config/nvim/lua/plugins/markdown.lua` を新設し、Markdown / 画像まわりの plugin を集約する。
- 既存の `render-markdown.nvim` 定義を `util.lua` から `markdown.lua` へ移し、今回追加する `snacks.nvim` と `img-clip.nvim` を同じ文脈で管理する。
- `snacks.nvim` は lazy.nvim の spec で `opts.image.enabled = true` を明示し、Markdown ドキュメント表示を有効にする。
- `img-clip.nvim` は `PasteImage` コマンドに加え、既存キーバインドと衝突しない `<leader>ip` のような専用キーで呼び出す方針とする。

### 2. 貼り付け画像の保存と参照ルールを決める

- `img-clip.nvim` は `dir_path = "assets"` を基本とし、`snacks.nvim` の既定探索ディレクトリ (`assets` を含む) に合わせる。
- Markdown で扱いやすいように `use_absolute_path = false` とし、必要に応じて `relative_to_current_file = true` を設定して、貼り付けたリンクが編集対象ファイル基準になるようにする。
- Markdown 用テンプレートは plugin 既定値を確認し、必要なら `![...]($FILE_PATH)` 形式を明示する。

### 3. macOS 依存を dotfiles に反映する

- `run_once_install-packages_mac.sh` の Homebrew package 一覧へ `pngpaste` を追加する。
- 依存解決の責務は install script に寄せ、brew の実インストールやローカル状態同期はこのチケットでは行わない。

### 4. 検証設計を先に固める

- 静的確認として `git diff --check` を実行する。
- plugin 解決確認として `nvim --headless "+Lazy! sync" +qa` を実行する。
- plugin health 確認として `nvim --headless "+checkhealth snacks" "+checkhealth img-clip" +qa` を実行する。
- 手動確認では以下を行う。
  - Ghostty 上の Neovim で Markdown 中の画像が表示されることを確認する。
  - WezTerm 上では inline 非対応前提で、`snacks.nvim` がエラーなく動作し、必要な fallback 表示ができることを確認する。
  - Markdown ファイルで画像を clipboard から貼り付け、`assets/` 配下への保存とリンク挿入を確認する。

## 変更予定ファイル

- `dot_config/nvim/lua/plugins/util.lua`
  - `render-markdown.nvim` の定義を移す場合の整理。
- `dot_config/nvim/lua/plugins/markdown.lua`
  - `render-markdown.nvim` / `snacks.nvim` / `img-clip.nvim` の定義を集約する新規ファイル。
- `run_once_install-packages_mac.sh`
  - `pngpaste` を Homebrew package に追加する。

## リスクと未解決事項

- WezTerm は `snacks.nvim` 公式 docs 上で inline 非対応のため、Ghostty と同じ見え方にはならない。実装時は「表示できること」と「inline 表示できること」を分けて扱う必要がある。
- `img-clip.nvim` の推奨キーマップ `<leader>p` は既存設定と競合するため、代替キーマップ採用が必要。
- JPG / PDF など PNG 以外の表示まで保証する場合は ImageMagick の追加導入を検討する必要がある。
- `render-markdown.nvim` と `snacks.nvim` の組み合わせで見た目や conceal が想定外になる可能性があるため、Markdown 実ファイルで確認が必要。

## 参考資料

- Docswell: https://www.docswell.com/s/mozumasu/ZN71M7-2026-04-02-dotfiles#p1
- snacks.nvim README / image docs: https://github.com/folke/snacks.nvim
- snacks.nvim image docs: https://github.com/folke/snacks.nvim/blob/main/docs/image.md
- img-clip.nvim README: https://github.com/hakonharnes/img-clip.nvim
