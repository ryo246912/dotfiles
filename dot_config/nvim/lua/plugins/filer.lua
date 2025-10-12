return {
  {
    "lambdalisue/fern.vim",
    config = function()
      -- 隠しファイルも表示する
      vim.g["fern#default_hidden"] = 1
      vim.g["fern#opener"] = "split"

      local keymap = vim.keymap.set

      -- <leader>eでdrawerを開くまたはフォーカスする
      keymap("n", "<leader>e", ":<C-u>:Fern . -drawer -reveal=%<CR>", { noremap = true, silent = true })
      -- <leader>sでdrawerを開閉する
      keymap("n", "<leader>s", ":<C-u>:Fern . -drawer -reveal=% -toggle<CR>", { noremap = true, silent = true })
    end,
  },
  {
    "nanotee/zoxide.vim",
    config = function()
      -- cdの際にdirectoryのスコアを増やす
      vim.g.zoxide_hook = "pwd"

      -- zoxideを起動
      vim.cmd("cnoremap zz :Zi<CR>")
    end,
  },
}
