vim.cmd([[
cabbr he help
cabbr te terminal
cabbr teh horizon terminal
cabbr tet horizon terminal
cabbr tev vertical terminal
cabbr tey vertical terminal
" 設定ファイルをリロードする
" TODO: 修正する
cabbr sv luafile ~/.config/nvim/init.lua
" 挿入モードの切り替え
cabbr <leader>P :set paste!
" :s で%s//(置換後)/gを呼び出し
cabbr <expr> s getcmdtype() .. getcmdline() ==# ':s' ? [getchar(), ''][1] .. "%s///g<Left><Left>" : 's'
]])
