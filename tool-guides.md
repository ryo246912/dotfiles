# Git / Claude Tool Guides

DOTFILE-28 は issue title だと `gitlinker.nvim` だけですが、issue body と follow-up comments で `zunda-hooks`、`xdg-ninja`、`rtk` も追加されているため、この 4 件をまとめます。

## `gitlinker.nvim`

### この repo で追加したもの

- `dot_config/nvim/lua/plugins/git.lua` に `linrongbin16/gitlinker.nvim` を追加した。
- normal mode / visual mode の両方で使える keymap を追加した。
  - `<leader>gy`: permalink をコピー
  - `<leader>gY`: permalink をブラウザで開く (`GitLink!`)

### 使い方

1. 現在行の permalink をコピーする。
   - normal mode で `<leader>gy`
2. 現在行の permalink をブラウザで開く。
   - normal mode で `<leader>gY`
3. 範囲リンクを使う。
   - visual mode で範囲選択してから `<leader>gy` または `<leader>gY`
4. 応用コマンドを使う。
   - `:GitLink blame`
   - `:GitLink default_branch`
   - `:GitLink current_branch`
   - `:GitLink remote=upstream`

### メモ

- この repo は GitHub remote 前提なので、生成される permalink も GitHub 向けになる。
- `GitLink` は copy、`GitLink!` は open の導線として覚えるとよい。

## `zunda-hooks`

### 目的

- Claude Code の `Notification` / `Stop` hooks を VOICEVOX 音声で通知したいときの導入メモ。

### 前提

- `jq`
- `curl`
- `python3`
- VOICEVOX が起動済みで、ローカル API にアクセスできること

### 導入手順

1. upstream repo を clone する。
2. VOICEVOX を起動した状態で `scripts/pregenerate.sh` を実行する。
3. Claude Code の hooks 設定へ upstream README の `Notification` / `Stop` 例を移植する。
4. この repo では tracked な `dot_claude/settings.json` と、worktree ごとの `.claude/settings.local.json` の両方に hooks の導線がある。
5. 常用するなら tracked file を直接上書きせず、まずは `settings.local.json` 側へ merge する。

### この repo で見る場所

- `dot_claude/settings.json`
- `dot_local/bin/executable_multi-worktree`

## `xdg-ninja`

### 目的

- XDG Base Directory Specification に従っていない config / cache / state の置き場を洗い出す。

### 導入手順

1. Homebrew で入れる。
   - `brew install xdg-ninja --HEAD`
2. 初回セットアップ後に実行する。
   - `xdg-ninja`
3. 出力を見て、`XDG_CONFIG_HOME` / `XDG_CACHE_HOME` / `XDG_DATA_HOME` / `XDG_STATE_HOME` に寄せるべきものだけを移す。

### この repo で見る場所

- `dot_config/zsh/dot_zshenv.tmpl` ですでに XDG 環境変数を export している。
- そのため `xdg-ninja` は「未対応の残り物を洗う」用途で使うのが自然。

## `rtk`

### 位置づけ

- issue comment で追加された AI tool 系の導入メモ。まずは upstream quick start をそのまま試す前提で整理する。

### 導入手順

1. Homebrew で入れる。
   - `brew install rtk`
2. グローバル設定を初期化する。
   - `rtk init --global`
3. 初期セットアップを進める。
   - `rtk gain`

### メモ

- repo 管理対象というよりユーザー環境の global setup に寄るツールなので、まずは local / global 側で試し、恒久化するものだけを dotfiles に戻すほうが安全。
