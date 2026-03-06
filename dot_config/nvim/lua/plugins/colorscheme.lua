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

      vim.api.nvim_set_hl(0, "CursorColumn", { ctermbg = 236, bg = "#3a3d41" })
    end,
  },
}
