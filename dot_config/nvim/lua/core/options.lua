-- バックアップファイルを作らない
vim.opt.backup = false
-- スワップファイルを作らない
vim.opt.swapfile = false
-- マウス操作の有効化
vim.opt.mouse = "a"
-- コマンドラインの履歴上限を10000件にする
vim.opt.history = 10000
-- session保存時のオプション
vim.opt.sessionoptions:append("localoptions")

-- ファイラー(netrw)
-- ファイルタイプの自動検出、ファイルタイプ用の プラグインとインデント設定 を自動読み込み
vim.cmd("filetype plugin indent on")
-- ファイルツリーの表示形式、1にするとls -laのような表示になります
vim.g.netrw_liststyle = 1
-- ヘッダを非表示にする
vim.g.netrw_banner = 0
-- サイズを(K,M,G)で表示する
vim.g.netrw_sizestyle = "H"
-- 日付フォーマットを yyyy/mm/dd(曜日) hh:mm:ss で表示する
vim.g.netrw_timefmt = "%Y/%m/%d(%a) %H:%M:%S"
-- プレビューウィンドウを垂直分割で表示する
vim.g.netrw_preview = 1
-- Enterで、垂直分割表示
vim.g.netrw_browse_split = 2

-- エディタ表示関係
-- カーソルラインをハイライト
vim.opt.cursorline = true
-- 行番号を表示
vim.opt.number = true
-- 相対行番号の表示
-- vim.opt.relativenumber = false
-- シンタックスハイライト有効
vim.opt.syntax = "on"
-- カーソル位置表示
vim.opt.ruler = true
-- ステータスを常時表示
vim.opt.laststatus = 2
-- 入力したコマンドが右下に表示
vim.opt.showcmd = true
-- タイトルを表示
vim.opt.title = true

-- 検索関連
-- 検索ハイライトを有効
vim.opt.hlsearch = true
-- 検索時に大文字小文字を区別しない
vim.opt.ignorecase = true
-- 検索時に大文字が含まれたら大文字検索を無視しない
vim.opt.smartcase = true
-- インクリメンタルサーチ
vim.opt.incsearch = true

-- 入力関連
-- タブ文字の表示幅
vim.opt.tabstop = 2
-- 自動インデントのスペース幅
vim.opt.shiftwidth = 2
-- 改行時に同じレベルにインデントする
vim.opt.autoindent = true
-- 改行時に入力された行の末尾に合わせて次の行のインデントを増減する
vim.opt.smartindent = true
-- 対応する括弧を表示
vim.opt.showmatch = true
-- tabの代わり指定のspace数を入力
vim.opt.expandtab = true
-- カーソルを行頭、行末で止まらないようにする
vim.opt.whichwrap = "b,s,h,l,<,>,[,]"
-- BSで削除できるものを指定 (indent:行頭の空白, eol:改行, start:挿入モード開始位置より手前の文字)
vim.opt.backspace = "indent,eol,start"

-- コマンドラインモードで<Tab>キーによるファイル名補完を有効にする
vim.opt.wildmenu = true

-- デフォルトを垂直分割にする
vim.opt.diffopt = "vertical"

-- カーソル形状の変更
vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
