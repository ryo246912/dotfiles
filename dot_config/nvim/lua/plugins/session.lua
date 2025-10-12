return {
  {
    "tpope/vim-obsession",
    config = function()
      -- セッション用ディレクトリを作成
      local session_dir = vim.fn.expand("~/.local/state/vim")
      if vim.fn.isdirectory(session_dir) == 0 then
        vim.fn.mkdir(session_dir, "p")
      end

      -- セッションの保存マッピング
      vim.cmd("cabbr ss :Obsession ~/.local/state/vim/Session.vim<CR>")

      -- セッションの読み込み&セッションの保存マッピング
      vim.cmd("cabbr sr :source ~/.local/state/vim/Session.vim \\| Obsession ~/.local/state/vim/Session.vim<CR>")
    end,
  },
}
