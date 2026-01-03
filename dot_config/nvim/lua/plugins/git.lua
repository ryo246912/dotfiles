return {
  {
    "tpope/vim-fugitive",
    config = function()
      local keymap = vim.keymap.set

      -- Gitステータス
      keymap("n", "<leader>gs", ":Git<CR>", { noremap = true })
      -- Git差分
      keymap("n", "<leader>gd", ":Git diff<CR>", { noremap = true })
      -- Git差分 (分割表示)
      keymap("n", "<leader>gv", ":Gdiffsplit<CR>", { noremap = true })
      -- Git show (最新コミットの詳細)
      keymap("n", "<leader>gh", ":Git show<CR>", { noremap = true })
      -- Git log -p
      keymap("n", "<leader>gl", ':Git log -p --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git log
      keymap("n", "<leader>gL", ':Git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git branch
      keymap("n", "<leader>gb", ":Git branch<CR>", { noremap = true })
      -- Git current branch
      keymap("n", "<leader>gB", ":Git branch --show-current<CR>", { noremap = true })
      -- lazygit
      keymap("n", "<leader>lg", ":tabnew | terminal lazygit<CR>", { noremap = true })
    end,
  },
}
