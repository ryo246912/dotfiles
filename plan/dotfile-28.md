# DOTFILE-28

## 概要

- `gitlinker.nvim` を既存の `lazy.nvim` 構成へ追加し、この dotfiles repo での使い方を文書化する。
- issue 本文で要求されている `zunda-hooks` の導入手順に加え、Linear コメントで追加された `xdg-ninja` と `rtk` の導入手順もまとめる。
- issue title は `gitlinker.nvim` のみを示しているため、文書では plugin 導入と外部 CLI / hooks の導入手順を明確に分離する。

## 要件

### 機能要件

- `dot_config/nvim/lua/plugins/git.lua` に `gitlinker.nvim` を追加し、既存の git plugin 群と同じ `lazy.nvim` スタイルで管理する。
- 通常モードと visual mode の両方で permalink を扱える導線を提供する。
- `GitLink` の基本操作に加えて、`blame` / `default_branch` / `current_branch` / `remote` のいずれか少なくとも 1 つの応用操作を文書化する。
- `zunda-hooks` の前提条件、VOICEVOX 起動、音声 pregenerate、Claude Code 側の有効化手順を repo 内にまとめる。
- `xdg-ninja` と `rtk` の導入方法、実行例、repo 利用者にとっての目的を repo 内にまとめる。

### 非機能要件

- 既存の `<leader>g*` キーマップと衝突しない導線にする。
- ドキュメントはこの repo のセットアップ導線から辿れる場所に置く。
- 追加する手順は macOS 環境を主軸にしつつ、upstream README の前提条件との差分が分かるようにする。

### 制約条件

- このターンでは計画のみ作成し、実装には進まない。
- `git fetch origin main` は sandbox 制約で `FETCH_HEAD` に書き込めないため、同期証跡はローカル `origin/main` 参照で代替する。
- 既存の Linear workpad comment は別 issue の内容を引きずっているため、同じ comment ID を再利用しつつ全面更新する。

## 調査結果

- `gitlinker.nvim` upstream README は `lazy.nvim` での導入例、`GitLink` / `GitLink!`、visual range、`blame` / `default_branch` / `current_branch` / `remote=...` を案内している。
- `zunda-hooks` upstream README は `jq` / `curl` / `python3` / VOICEVOX を要件にし、`bash scripts/pregenerate.sh` と `.claude/settings.json` ベースの hooks 構成を案内している。
- `xdg-ninja` upstream README は手動 clone 実行のほか、`brew install xdg-ninja --HEAD` を Homebrew 手順として案内している。
- `rtk` upstream README は `brew install rtk`、`rtk init --global`、`rtk gain` を Quick Start として案内している。
- repo 側では Neovim plugin は `dot_config/nvim/lua/plugins/*.lua` に集約されており、git 系は `dot_config/nvim/lua/plugins/git.lua` にまとまっている。
- 現在の repo には `gitlinker.nvim` / `zunda-hooks` / `xdg-ninja` / `rtk` の参照がなく、導入ドキュメントの入口は `README.md` と `setup.md` が最も自然。

## 実装計画

### 1. scope と配置の確定

- issue 本文と追記コメントを反映し、今回の scope を `gitlinker.nvim` + `zunda-hooks` + `xdg-ninja` + `rtk` に正規化する。
- docs の置き場所を決める。
- 候補は `setup.md` 追記または新規 markdown 作成 + `README.md` / `setup.md` からリンク。

### 2. `gitlinker.nvim` の導入

- `dot_config/nvim/lua/plugins/git.lua` に plugin spec を追加する。
- 遅延ロード条件、`opts`、必要なら `keys` を repo の既存書式に合わせて定義する。
- 既存の `<leader>g` / `<leader>gb` / `<leader>gB` などとの衝突を避けるため、最終キーマップを整理する。

### 3. `gitlinker.nvim` 利用ドキュメントの追加

- 現在行の permalink をコピーする手順を記載する。
- visual selection の permalink をコピー / open する手順を記載する。
- 応用例として `blame`、`default_branch`、または `remote=upstream` を最低 1 つ含める。
- 実際にこの repo で使う前提の注意点を記載する。

### 4. 外部ツール導入ガイドの追加

- `zunda-hooks` は前提パッケージ、VOICEVOX 起動確認、`scripts/pregenerate.sh`、Claude Code hooks 有効化の順で整理する。
- `xdg-ninja` はこの repo の XDG 方針と関連づけて導入目的と実行例を整理する。
- `rtk` は導入方法、`rtk init --global`、`rtk gain`、Claude Code との関係を整理する。

### 5. 検証

- `nvim --headless "+qa"` で Neovim 設定が崩れていないことを確認する。
- ドキュメントに記載したコマンドやパスが repo 構成と矛盾しないことを確認する。
- `gitlinker.nvim` の基本操作と応用操作の最低 1 つを手動確認対象にする。

## 変更対象ファイル

- `dot_config/nvim/lua/plugins/git.lua`
- `README.md`
- `setup.md`
- 追加が必要なら新規ドキュメントファイル

## 技術的課題と対応策

- キーマップ衝突: 既存の Fugitive / Diffview / Gitsigns の `<leader>g*` を確認し、未使用 prefix か command-only 導線を選ぶ。
- docs の肥大化: `setup.md` が長いため、必要なら専用ドキュメントを新設して入口だけ既存ファイルに置く。
- upstream 手順との差分: repo 既存の package manager 方針と upstream 推奨方法が異なる場合は、両方を併記して理由を明示する。

## テスト計画

- 設定ロード確認: `nvim --headless "+qa"`
- 手動確認: `GitLink` を normal / visual で試す
- 手動確認: `GitLink blame` または `GitLink default_branch`
- 文書確認: `README.md` / `setup.md` / 新規 docs から追加手順へ到達できることを確認する

## リスクと未解決事項

- issue title と本文 / コメントの scope が一致していないため、review 時に「今回の実装範囲」を明示する必要がある。
- `git fetch origin main` が sandbox 制約で実行できないため、実装前同期の完全性はローカル参照ベースになる。
- `rtk` と `zunda-hooks` は Claude Code 固有の要素を含むため、repo にどこまで恒久手順として残すかは review で調整が入る可能性がある。

## 参考資料

- https://github.com/linrongbin16/gitlinker.nvim
- https://github.com/hawkymisc/zunda-hooks
- https://github.com/b3nj5m1n/xdg-ninja
- https://github.com/rtk-ai/rtk
