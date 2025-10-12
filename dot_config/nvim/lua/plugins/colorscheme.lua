return {
  {
    "tomasr/molokai",
    priority = 1000,
    config = function()
      -- 256色
      vim.opt.termguicolors = true
      -- 背景色
      vim.opt.background = "dark"
      -- カラースキーム設定
      vim.cmd.colorscheme("molokai")

      -- 80列目の色は灰色周辺の色に変更
      -- TODO: 別途修正する
      -- vim.cmd("highlight ColorColumn ctermbg=235 guibg=#2c2d27")
    end,
  },
}
