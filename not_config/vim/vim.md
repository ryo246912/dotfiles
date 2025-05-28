# memo

## モード
- インサートモード
- ビジュアルモード
- 矩形ビジュアルモード
- コマンドモード(コマンドラインモード)
  - `q:`などで開けるのは、コマンドラインウィンドウ

・map・noremapの違いは、再帰的なマッピングかどうかということです。
noremap系の方が挙動としては直感的だと思うので、基本的には、noremap系を使う

map系   noremap系   モード
map noremap ノーマルモード、ビジュアルモード
nmap    nnoremap    ノーマルモード
vmap    vnoremap    ビジュアルモード
imap    inoremap    インサートモード
cmap    cnoremap    コマンドラインモード
tmap    tnoremap    ターミナルモード

## キーバインド
- <leader>はコマンド割り当てに使うキー
<Leader>キーを使った複数キー入力にコマンドを割り当てるなら機能が被らない
-  Vim では :substitute コマンド（短縮形: :s）を用いて`:%s/(置換前)/(置換後)/g`で置換するのが基本(/検索後は`:%s//(置換後)/g`)
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

## help
tagsファイルがあると以下が使える
- :help <xxx> :helpを開く
- ,{[,]} : タグジャンプ
## 他
- autocmd(自動コマンド機能)
  - VimEnterやVimLeaveイベントを使用して、Vimのセッション開始時や終了時に特定のアクションを実行
  autocmd VimEnter * NERDTree
  autocmd VimEnter * source ~/.local/state/vim/Session.vim | Obsession ~/.local/state/vim/Session.vim
