-- leaderキーを設定
vim.g.mapleader = ","

-- ウィンドウ最大化/もとに戻す関数
vim.g.toggle_window_size = 0
local function toggle_window_size()
  if vim.g.toggle_window_size == 1 then
    vim.cmd("normal! \\<C-w>=")
    vim.g.toggle_window_size = 0
  else
    vim.cmd("resize")
    vim.cmd("vertical resize")
    vim.g.toggle_window_size = 1
  end
end

-- g1からg9のキーバインドで1-9のタブに移動するキーバインド追加
local function go_to_nth_tab(n)
  local target_tab = n
  if target_tab <= vim.fn.tabpagenr('$') then
    vim.cmd("tabnext " .. target_tab)
  else
    vim.api.nvim_err_writeln("Target tab does not exist")
  end
end

-- Key mappings
-- {n,i,x,c...}[nore]map: [non-recursive] map (n:normal,i:insert,x:visual,c:command lineモード)
-- xnoremap <key-sequence> <vim-command>
local keymap = vim.keymap.set

-- xをdに割り当て
keymap("n", "x", "d", { noremap = true })
keymap("x", "x", "d", { noremap = true })
keymap("n", "xx", "dd", { noremap = true })
keymap("x", "xx", "dd", { noremap = true })

-- ddを無効化してバッファに影響しないようにする
keymap("n", "dd", '"_dd', { noremap = true })
keymap("x", "dd", '"_dd', { noremap = true })

-- d, c, sがレジスタに影響しないようにする
keymap("n", "d", '"_d', { noremap = true })
keymap("x", "d", '"_d', { noremap = true })
keymap("n", "D", '"_D', { noremap = true })
keymap("n", "s", '"_s', { noremap = true })
keymap("n", "S", '"_S', { noremap = true })
keymap("n", "c", '"_c', { noremap = true })
keymap("x", "c", '"_c', { noremap = true })
keymap("n", "C", '"_C', { noremap = true })
keymap("x", "C", '"_C', { noremap = true })

-- 最終行の行末に移動
keymap("n", "GG", "G$", { noremap = true })
keymap("x", "GG", "G$", { noremap = true })
-- <leader>hl → 行頭・行末移動
keymap("n", "<leader>h", "^", { noremap = true })
keymap("n", "<leader>l", "$", { noremap = true })
keymap("x", "<leader>h", "^", { noremap = true })
keymap("x", "<leader>l", "$h", { noremap = true })

-- Clipboardにyank
keymap({ "n", "x" }, "gy", '"+y', { noremap = true })

-- ESC連打でハイライト解除
keymap("n", "<Esc><Esc>", ":nohlsearch<CR><Esc>", { noremap = true, silent = true })

-- Emacs-like movement in Insert/Command
keymap({ "i", "c" }, "<C-a>", "<Home>", { noremap = true })
keymap({ "i", "c" }, "<C-e>", "<End>", { noremap = true })
keymap("c", "<C-k>", [[<C-\>e(" ".getcmdline())[:getcmdpos()-1][1:]<CR>]], { noremap = true })

-- 新しいタブを開く
keymap("n", "<leader>t", ":tabnew<CR>", { noremap = true })
-- タグジャンプする/1つ前のタグに戻る
keymap("n", "<leader>]", ":tag<CR>", { noremap = true })
keymap("n", "<leader>[", ":pop<CR>", { noremap = true })

-- 相対・絶対行の表示切替
keymap("n", "<leader>n", ":<C-u>setlocal relativenumber!<CR>", { noremap = true })

-- popupでterminalを開く
-- TODO: 別途修正する
-- keymap("n", "<leader>p", [[:call popup_create(term_start([&shell], #{ hidden: 1, term_finish: "close"}), #{ border: [], minwidth: winwidth(0), minheight: &lines/2 })<CR>]], { noremap = true })

-- インサートモードに戻る
keymap("t", "<F2>", [[<C-\><C-n>]], { noremap = true })

-- 選択範囲を検索
keymap("v", "/", [[<ESC>/\%V]], { noremap = true })
keymap("v", "?", [[<ESC>?\%V]], { noremap = true })


keymap("n", "<leader>z", toggle_window_size, { noremap = true })
keymap("n", "<A-z>", toggle_window_size, { noremap = true })

-- g1-g9 mappings
for i = 1, 9 do
  keymap("n", "g" .. i, function() go_to_nth_tab(i) end, { noremap = true })
end
