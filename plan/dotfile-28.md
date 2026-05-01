# DOTFILE-28

## 概要

- `gitlinker.nvim` を既存の `lazy.nvim` ベース Neovim 設定へ組み込み、通常行・ビジュアル選択・発展ルートの使い方まで repo 内で参照できる状態にする
- issue 本文と追記コメントで追加された `zunda-hooks`、`xdg-ninja`、`rtk` の導入手順も同じ ticket のスコープとして整理する
- 既存 workpad は過去セッションの成果を示していたが、今回の repo copy は `origin/main` と同一で差分がないため、現状から実装をやり直す

## 要件

### 機能要件

- `dot_config/nvim/lua/plugins/git.lua` に `linrongbin16/gitlinker.nvim` を追加する
- 既存の Git キーマップと競合しない `GitLink` / `GitLink!` のキーマップを定義する
- `gitlinker.nvim` の使い方を current line、visual selection、発展ルート付きで文書化する
- `zunda-hooks`、`xdg-ninja`、`rtk` の導入手順と最低限の使い方を日本語でまとめる
- `README.md` と `setup.md` から新しいガイドへ辿れるようにする

### 非機能要件

- 既存の plugin 設定スタイルに合わせ、`lazy.nvim` の標準的な `cmd` / `keys` / `opts` 構成で追加する
- ドキュメントは reviewer が ticket の拡張スコープを一目で把握できる粒度にする
- 検証は repo ローカルの一時 XDG ディレクトリを使い、ホーム配下を汚さずに実施する

### 制約条件

- 作業対象は `dotfiles/` repo copy のみとする
- 公式 README を一次情報として扱い、導入・利用例は upstream の現行手順に揃える
- Linear の state はすでに `Implement` のため、合意済みスコープの実装と出荷準備まで進める

## 実装計画

### 1. `gitlinker.nvim` の導入

- `dot_config/nvim/lua/plugins/git.lua` に plugin spec を追加する
- `<leader>gy` を copy、`<leader>gY` を browser open に割り当てる
- `mode = { "n", "v" }` を使い、通常行とビジュアル選択の両方で同じ操作に揃える

### 2. ドキュメント追加

- `tool-guides.md` を新規追加し、ticket のスコープ拡張を冒頭で明示する
- `gitlinker.nvim` 章では導入場所、通常行、ビジュアル選択、`blame` などの発展ルートを記載する
- `zunda-hooks`、`xdg-ninja`、`rtk` 章では upstream README を要約して、導入コマンドと確認方法を残す

### 3. 導線追加

- `README.md` の setup リンク群に `tool-guides.md` を追加する
- `setup.md` からも同じガイドへ辿れるようにリンクを追加する

### 4. 検証と出荷

- `git diff --check` でパッチ健全性を確認する
- repo ローカルの一時ディレクトリを `XDG_DATA_HOME` / `XDG_STATE_HOME` / `XDG_CACHE_HOME` に割り当てて `nvim --headless "+qa"` を実行する
- headless Neovim から `GitLink` の current line、visual range、`blame` を生成して URL を確認する
- commit、push、draft PR、Linear 更新まで完了する

## 技術的課題と対応策

- `gitlinker.nvim` の URL 生成確認は clipboard 依存にせず、headless Neovim から Lua API を呼んで URL を取得する
- `lazy.nvim` 初回起動時に plugin install が走る可能性があるため、一時 XDG ディレクトリを repo 配下に切って隔離する
- `xdg-ninja` の Homebrew 版は HEAD 指定が必要という upstream 注意書きがあるため、通常 install と upgrade の両方を doc に残す

## テスト計画

- `git diff --check`
- `nvim --headless "+qa"` を repo ローカル XDG 環境で実行
- `GitLink` の line / visual / blame URL を headless で確認
- `rg -n "gitlinker|GitLink|zunda-hooks|xdg-ninja|rtk" README.md setup.md tool-guides.md dot_config/nvim/lua/plugins/git.lua -S`

## デプロイ・リリース計画

- feature branch `DOTFILE-28` に commit
- `origin/DOTFILE-28` へ push
- draft PR を作成し、`symphony` label を付与する
- PR URL を Linear issue に添付し、workpad と完了コメントを更新する

## リスクと未解決事項

- 既存 workpad と repo copy の乖離理由は不明だが、今回の repo 実体を正として上書きする
- headless 検証で plugin bootstrap が失敗する場合は、失敗ログを workpad に残して代替確認範囲を明示する

## 参考資料

- https://github.com/linrongbin16/gitlinker.nvim
- https://github.com/hawkymisc/zunda-hooks
- https://github.com/b3nj5m1n/xdg-ninja
- https://github.com/rtk-ai/rtk
