# 補助ツールガイド

`DOTFILE-28` は issue タイトルだと `gitlinker.nvim` だけに見えますが、実際のスコープは issue 本文の `zunda-hooks` と、追記コメントの `xdg-ninja` / `rtk` まで広がっています。ここでは 4 つのツールをまとめて扱います。

## gitlinker.nvim

`gitlinker.nvim` は現在のファイル位置から Git ホスティングサービス向けの permalink を生成する Neovim plugin です。この repo では `dot_config/nvim/lua/plugins/git.lua` に `lazy.nvim` 用の設定を追加して使います。

### 使い方

- 現在行の permalink を clipboard にコピーする
  ```vim
  <leader>gy
  ```
- 現在行の permalink をブラウザで開く
  ```vim
  <leader>gY
  ```
- ビジュアルモードで選択範囲を選んでから同じキーマップを押すと、range 付きの URL を生成できます
- コマンドを直接使うと発展ルートも選べます
  ```vim
  :GitLink blame
  :GitLink default_branch
  :GitLink current_branch
  :GitLink remote=upstream
  :GitLink! blame remote=upstream
  ```

### メモ

- `GitLink` は URL をコピーし、`GitLink!` は URL をそのまま開きます
- 複数 remote がある場合は `remote=...` を指定します。未指定時は通常 `origin` が使われます
- 通常行でもビジュアル選択でも同じ `<leader>gy` / `<leader>gY` で操作できます

## zunda-hooks

`zunda-hooks` は Claude Code の tool 実行時に、VOICEVOX を使って音声で通知する hooks 集です。README では `jq`、`curl`、`python3`、音声再生コマンド、VOICEVOX 本体を前提にしています。

### macOS での導入

1. 前提コマンドを揃える
   ```sh
   brew install jq
   ```
   `afplay`、`curl`、`python3` は通常そのまま使えます。
2. VOICEVOX を起動して API を確認する
   ```sh
   open -a VOICEVOX
   curl http://localhost:50021/version
   ```
3. 音声キャッシュを事前生成する
   ```sh
   bash scripts/pregenerate.sh
   ```
4. 対象プロジェクトで Claude Code を開く
   `.claude/settings.json` の hook 設定が読み込まれ、`Read` や `Bash` 実行時に音声通知が有効になります。

### 使い方

- 生成済み WAV は `~/.claude/hooks/zaudio/` に保存され、複数プロジェクトで共有されます
- `pregenerate.sh` を省くと初回セッション開始時に警告音声が流れます
- 音声が出ない場合は `curl http://localhost:50021/version` と `ls -lh ~/.claude/hooks/zaudio/` を最初に確認すると切り分けしやすいです

## xdg-ninja

`xdg-ninja` は `$HOME` 直下に散らばる設定ファイルやキャッシュを検出して、XDG Base Directory に移せるかを教えてくれる shell script です。

### 導入

- Homebrew
  ```sh
  brew install xdg-ninja --HEAD
  brew upgrade xdg-ninja --fetch-HEAD
  ```
  upstream README では、release を切らない運用のため通常の Homebrew formula は古くなりやすく、`--HEAD` 指定が推奨されています。
- 手動
  ```sh
  git clone https://github.com/b3nj5m1n/xdg-ninja
  cd xdg-ninja
  ./xdg-ninja.sh
  ```

### 使い方

- Homebrew 導入後は `xdg-ninja`、手動導入なら `./xdg-ninja.sh` を実行して `$HOME` を走査します
- 追加ルールを書きたい場合は `programs/` ディレクトリの JSON を編集します
- `programs/` の場所を変えたい場合は `XN_PROGRAMS_DIR` 環境変数で上書きできます
- Linux x86_64 なら `xdgnj` で JSON ひな形を生成できますが、通常の走査だけなら shell と `jq` と `find` があれば十分です

## rtk

`rtk` は AI agent が実行する shell command の出力を圧縮して、トークン消費を減らす CLI proxy です。README では Homebrew を推奨し、`rtk init` で各 agent に hook を入れる流れになっています。

### 導入

- Homebrew
  ```sh
  brew install rtk
  ```
- install script
  ```sh
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  ```
- Cargo
  ```sh
  cargo install --git https://github.com/rtk-ai/rtk
  ```
  crates.io には同名の別 project があるため、README では `cargo install --git` が案内されています。

### 初期化と使い方

```sh
rtk --version
rtk gain
rtk init -g
rtk init -g --codex
git status
```

- `rtk init -g` は Claude Code / Copilot 向け、`rtk init -g --codex` は Codex 向けです
- 初期化後に agent を再起動すると、Bash 実行の `git status` などが自動で `rtk git status` へ書き換えられます
- `Read` / `Grep` / `Glob` のような built-in tool は Bash hook を通らないため、必要なら shell command か `rtk read` / `rtk grep` / `rtk find` を直接使います
