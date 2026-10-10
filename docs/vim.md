# memo

## モード

- インサートモード
- ビジュアルモード
- 矩形ビジュアルモード
- コマンドモード(コマンドラインモード)
  - `q:`などで開けるのは、コマンドラインウィンドウ

・map・noremapの違いは、再帰的なマッピングかどうかということです。
noremap系の方が挙動としては直感的だと思うので、基本的には、noremap系を使う

map系 noremap系 モード
map noremap ノーマルモード、ビジュアルモード
nmap nnoremap ノーマルモード
vmap vnoremap ビジュアルモード
imap inoremap インサートモード
cmap cnoremap コマンドラインモード
tmap tnoremap ターミナルモード

## キーバインド

- <leader>はコマンド割り当てに使うキー
  <Leader>キーを使った複数キー入力にコマンドを割り当てるなら機能が被らない
- Vim では :substitute コマンド（短縮形: :s）を用いて`:%s/(置換前)/(置換後)/g`で置換するのが基本(/検索後は`:%s//(置換後)/g`)
- % は置換範囲を表し、ファイル全体を置換する、という意味を持ちます (cf. :h :%)。
  % を書かない場合、カーソルのある行だけが置換対象となります。

## テキストオブジェクト

operator + (motion/textobject)

- operator
  - c : change
  - y : yank
  - v : visualモードで選択
  - <> : shift {left,right} (インデント上げ下げ)
  - ~ : switch case
- motion or テキストオブジェクト
  テキストオブジェクト
  - d : delete
  - word : 単語 例、ciw
  - sentence : !?スペースタタブで区切られる
  - block : （）などの括弧 例、cib
    以下の境界を指定するワードとともに使用することもある
  - i : in(境界を含めない)
    - ci{囲み} → <入力> 文字の範囲内の入力を削除して挿入モードへ
    - cgn → . : 選択文字を削除して挿入モードへ
  - a : (境界を含める)
  - s : surround
    - cs{前}{後} : 囲みを前→後に変更 例.cs’"
    - ys{textobject}{囲み} : 囲みを挿入(大体iwだと思う)例.ysiw"
      - 範囲選択→ S{囲み} : 選択部分を囲む
    - ds{囲み} : 囲みを削除

## 検索マッチをインタラクティブに置換する

VSCode の Ctrl+F 検索→マッチ箇所ごとに確認しながら置換、に相当するやり方。

### 方法1: `:s` の `c` フラグ(confirm)で1件ずつ確認

`:%s/(置換前)/(置換後)/gc` とすると、マッチ箇所ごとに以下のプロンプトが出て、都度選べる。

- `y` : 置換する
- `n` : 置換せず次へ
- `a` : 残り全部置換
- `q` / `<Esc>` : 中断
- `l` : この箇所を置換して終了
- `^E` / `^Y` : 画面を1行下/上へスクロール(位置確認用、カーソルは動かない)

### 方法2: `cgn` + `.` でインタラクティブに置換

1. `/pattern<CR>` で置換したい文字列を検索(カーソル位置から検索を開始し、直後のマッチに移動)
2. `cgn` で最初のマッチを選択した状態で削除して挿入モードに入る
3. 置換後の文字列を入力して `<Esc>`
4. 次のマッチも置換したい場合は `.` を押すだけで同じ置換を繰り返せる(不要な箇所はスキップして次のマッチまで `n` で移動してから `.` )

`cgn` はノーマルモードでの操作なので、`.` によるリピートが効くのが `:s///gc` との違い。

`cgn` は `c`(change) + `gn`(motion) の組み合わせ。

- `n` : 検索コマンド `/pattern<CR>` のあとに使う「次のマッチへ移動」コマンドの `n`(next)がそのまま流用されている
- `g` : vim では既存の動作を拡張・特殊化するときによく付く接頭辞(`gg`, `gv`, `gj`, `gu` など)。`gn` は「`n`(次のマッチへ移動)」を「ビジュアル選択する」動作に拡張したもの
- 逆方向(前のマッチ)を選択するのは `gN`
- `gn` 単体でもマッチを選択できる(`vgn` と同じ効果)。`ygn`(ヤンク)、`dgn`(削除)など `c` 以外の operator とも組み合わせ可能

## ヤンク履歴をインタラクティブに選択してペースト

標準の nvim だけでは「ヤンクした履歴」を何件もは保持していない(ヤンクは基本的に `"0` レジスタに1件だけ、`"1`〜`"9` は delete/change の履歴)。過去のヤンクを一覧からインタラクティブに選んでペーストしたい場合はプラグインを使うのが手軽。

### 標準機能でできる範囲

- `:reg` / `:registers` : 現在のレジスタの中身を一覧表示(確認用。選択してペーストはできない)
- `"0p` : 直前のヤンク(delete/change では上書きされない専用レジスタ)
- `"1p`〜`"9p` : 行単位の直近の delete/change 履歴
- `"-p` : 1行未満の小さな削除(`x`, 途中までの `dw` など)
- 挿入モード/コマンドラインモードで `<C-r>{register}` : レジスタの内容をその場に挿入(例 `<C-r>0`)

### fzf 的にインタラクティブに選ぶ

fzf のようなあいまい検索 UI でレジスタ一覧から選んでペースト、というプラグインは存在する。

- `telescope.nvim` : ビルトインの `registers` picker → `:Telescope registers` でレジスタ一覧をあいまい検索して選択・ペースト
- `fzf-lua` : 同様に `registers` picker → `:FzfLua registers`
- ただしどちらも対象は「レジスタ」止まりで、何回も前のヤンクまでは遡れない。ヤンクの全履歴を保持してインタラクティブに選びたい場合は
  - `gbprod/yanky.nvim` : ヤンク履歴を保持するプラグイン。telescope/Snacks.picker/vim.ui.select と連携してヒストリーから選択してペーストできる(fzf-lua と組み合わせるには `vim.ui.select` を fzf-lua に登録する必要がある)
  - `AckslD/nvim-neoclip.lua` : クリップボード(ヤンク)履歴管理プラグイン。telescope/fzf-lua の picker 経由でインタラクティブに選択・ペースト可能

まとめると、標準機能だけでは直近数件しか追えないので、履歴からインタラクティブに選びたいなら `yanky.nvim` か `nvim-neoclip.lua` を telescope/fzf-lua と組み合わせるのが定番。

このdotfilesでは `nvim-neoclip.lua` を導入済み(`config/nvim/lua/plugins/neoclip.lua`)。`<leader>y` で fzf-lua 経由のヤンク履歴ピッカーを開く。`<CR>`で`"`レジスタに設定し、直接ペーストする場合はfzf内で`<C-p>`を押す。

## コメントアウトの toggle

`tpope/vim-commentary` を導入済み(`config/nvim/lua/plugins/editor.lua`)。`gc` operator でコメントアウトの toggle ができる(すでにコメントアウトされていれば解除される)。

- カーソル行だけを toggle : `gcc`
- 選択行(ビジュアルモード)を toggle : 範囲選択→ `gc`
- motion/テキストオブジェクトと組み合わせて toggle : 例. `gcap`(段落), `gc3j`(カーソル行+下3行)

## 画像の表示・貼り付け(Markdown)

`config/nvim/lua/plugins/markdown.lua` で `folke/snacks.nvim`(画像表示)と `HakonHarnes/img-clip.nvim`(クリップボード画像の貼り付け)を導入済み。

### 画像を表示する

- Markdown を開くと `![alt](path)` の画像が snacks.nvim で表示される
  - ghostty : バッファ内に inline 表示
  - wezterm など inline 非対応の端末 : カーソルを画像リンクに置いたときにフロートで表示(snacks が端末を判定して自動で切り替える)
- `<leader>ih` : カーソル位置の画像をフロートで表示(inline 表示中でも大きく見たいときに使う)
- 相対パスは編集中のファイル基準で解決される。見つからない場合は `assets/` `images/` `img/` などの定番ディレクトリも探索される
- PNG 以外(JPG / WebP など)の表示には ImageMagick(`magick`)が必要。mac は `config-mac/mise/config.mac.toml` の `brew:imagemagick` で導入される
- tmux 内で表示するには `allow-passthrough on` が必要(`config/tmux/tmux.conf` で設定済み)
- 表示されないときは `:checkhealth snacks` で端末・ImageMagick の対応状況を確認する

PDF は snacks.nvim ではなく image.nvim の簡易ビューア(`config/nvim/lua/plugins/image.lua`)で開く。

### クリップボードの画像を貼り付ける

1. スクリーンショットなどの画像をクリップボードにコピーする(mac なら `cmd+ctrl+shift+4` など)
2. Markdown を開いて、画像を入れたい行で `<leader>ip`(または `:PasteImage`)
3. ファイル名を聞かれるので入力して `<CR>`(空のまま `<CR>` で日時のファイル名になる)
4. 編集中のファイルと同じ階層の `assets/` に PNG で保存され、`![](assets/<ファイル名>.png)` が挿入される

- クリップボード上のファイルパスや画像 URL を貼り付けた場合も、画像としてコピー/ダウンロードしてリンクを挿入する
- 必要なコマンド : mac は `pngpaste`(`config-mac/mise/config.mac.toml` の `brew:pngpaste`)、Linux は `xclip`(X11)か `wl-clipboard`(Wayland)
- 動かないときは `:checkhealth img-clip` で依存コマンドを確認する

## help

tagsファイルがあると以下が使える

- :help <xxx> :helpを開く
- ,{[,]} : タグジャンプ

## 他

- autocmd(自動コマンド機能)
  - VimEnterやVimLeaveイベントを使用して、Vimのセッション開始時や終了時に特定のアクションを実行
    autocmd VimEnter _ NERDTree
    autocmd VimEnter _ source ~/.local/state/vim/Session.vim | Obsession ~/.local/state/vim/Session.vim

## Neovim の設定を再読み込みする

`config/nvim/` 以下の Lua 設定を変更した場合は、変更した内容に応じて次の方法で再読み込みする。

- 現在開いている Lua ファイルだけを再実行する: `:luafile %`
- `init.lua` を再実行する: `:source $MYVIMRC`
- プラグインの設定を再読み込みする: `:Lazy reload <プラグイン名>`

`require()` で読み込み済みの Lua モジュールはキャッシュされるため、`:source $MYVIMRC` だけでは `lua/core/` や `lua/plugins/` 以下の変更が反映されない場合がある。また、autocmd、キーマップ、プラグインの初期化処理によっては、同じ設定を再実行すると処理が重複する場合がある。

確実にすべての変更を反映するには、`:qa` で Neovim を終了してから再起動する。編集中のファイルがある場合は、先に `:wa` ですべて保存してから `:qa` を実行する。

## プラグイン由来のエラーを調べて直す

起動時やコマンド実行時に `Error in VimEnter Autocommands` のようなエラーが出たら、まずスタックトレースを下から読み、どこが原因かを切り分ける。

- 自分の設定ファイル(例: `~/.config/nvim/lua/core/autocmds.lua:26`)は、エラーを起こした処理を呼び出した場所
- その上にあるプラグインのファイル(例: `.../lazy/<プラグイン名>/lua/...:65`)が、実際にエラーを出している場所
- `[C]: in function 'assert'` のように `assert` で落ちている場合は、プラグインが想定していない値(取得できないパスなど)を受け取ったことが多い

### 原因がプラグイン側か確認する

1. `:Lazy` を開き、対象プラグインのインストール済みのコミットを確認する(プラグインの行で `<CR>` を押すと詳細が出る)
2. スタックトレースのファイルと行番号を、手元のファイル(`~/.local/share/nvim/lazy/<プラグイン名>/`)で開いて確認する
3. 本家リポジトリの最新版で同じ箇所が変わっていないか確認する。`git log -S "<行の文字列>" -- <ファイル>` で、その行が追加・削除されたコミットを探せる
4. 最新版で直っていれば、手元のプラグインが古いだけと判断できる。issue や PR もあわせて検索する

### 直し方

- 更新して直る場合: `:Lazy update <プラグイン名>` で更新する(すべて更新するなら `:Lazy update`)
- 更新で壊れた場合: `:Lazy update` は `lazy-lock.json` も新しいコミットで書き換えるため、先に lock を更新前の内容に戻してから(git 管理していれば `git checkout <更新前のコミット> -- lazy-lock.json`) `:Lazy restore <プラグイン名>` を実行する。lock がない場合は、プラグイン定義に `commit = "<コミット>"` や `tag = "<タグ>"` を指定して一時的に固定する
- 本家で直っていない場合: 自分の設定側で、エラーになる呼び出し方を避ける(引数やオプションを変える、対象のバッファを絞るなど)

### プラグインを更新・再インストールできないとき

`:Lazy update` で `You have local changes in ... Please remove them to update.` と出る場合は、プラグインのディレクトリ(`~/.local/share/nvim/lazy/<プラグイン名>/`)内のファイルが書き換わっていて、lazy.nvim が上書きを避けて更新を止めている。

1. 何が変わったかを確認する: `git -C ~/.local/share/nvim/lazy/<プラグイン名> status --short`(`??` は追加されたファイルで、`diff` には出ない)と `git -C ~/.local/share/nvim/lazy/<プラグイン名> diff --stat`
2. プラグイン本体を自分で直していないなら、中身は本家から取り直せばよい。Neovim をすべて終了してからディレクトリごと消し、起動して `:Lazy install`(または `:Lazy sync`)で入れ直す

   ```sh
   rm -rf ~/.local/share/nvim/lazy/<プラグイン名>
   ```

- Lazy の画面で `x`(削除)→ `I`(インストール)でも入れ直せるが、更新処理が動いている最中だと削除しきれないことがある。clone 中に `BUG: ... initial ref transaction called with existing refs` のような git の内部エラーが出たら、clone 先に前の ref が残っている状態なので、上の手順で Neovim を閉じてから消し直す
- それでも同じエラーになる場合は、Neovim を通さずに `git clone` を直接試し、そこでも再現するなら git 自体を更新する

#### ローカル変更が入る原因と防ぎ方

自分で編集していないのに書き換わる場合は、ファイルを再帰的に整形するツールがプラグインのディレクトリまで処理していることが多い(変更されたのが `.json` / `.yml` / `.md` などの整形対象だけなら、ほぼこれ)。

- この dotfiles の `mise run fix:*` タスク(`config/mise/tasks/fix.toml`)は、実行したディレクトリ以下の `**/*.md` などをすべて整形する。`$HOME` など広いディレクトリでは実行しない
- Neovim の保存時の自動整形で、プラグインのファイルを開いて保存すると書き換わる。中身を読むだけなら保存しない

### 起動を止めないための保険

起動時の autocmd などでプラグインの関数を呼ぶ場合は、`pcall` で包んでおくと、プラグインの不具合で起動全体がエラーになるのを防げる。失敗したときは `vim.notify` で内容を通知しておくと、エラーに気づける。

```lua
local ok, err = pcall(function()
  require("neo-tree.command").execute({ source = "filesystem", action = "show" })
end)
if not ok then
  vim.notify("neo-tree の起動に失敗しました: " .. tostring(err), vim.log.levels.WARN)
end
```
