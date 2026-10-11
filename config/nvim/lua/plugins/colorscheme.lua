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

      vim.api.nvim_set_hl(0, "CursorLine",   { bg = "#3a3d41" })
      vim.api.nvim_set_hl(0, "CursorColumn", { ctermbg = 236, bg = "#3a3d41" })
      vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = "#888888", italic = true })

      -- diff (diffview / git delta 風)
      vim.api.nvim_set_hl(0, "DiffAdd",    { bg = "#1a2f1a" })
      vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#2f1a1a" })
      vim.api.nvim_set_hl(0, "DiffChange", { bg = "#1a2535" })
      vim.api.nvim_set_hl(0, "DiffText",   { bg = "#2f4a2f", fg = "#88cc88", bold = true })

      -- タブライン: molokaでfgが背景と同色になるため明示的に上書き
      vim.api.nvim_set_hl(0, "TabLine",     { fg = "#bcbcbc", bg = "#3a3d41", underline = false })
      vim.api.nvim_set_hl(0, "TabLineSel",  { fg = "#ffffff", bg = "#005f87", bold = true })
      vim.api.nvim_set_hl(0, "TabLineFill", { fg = "#bcbcbc", bg = "#1a1a1a" })
    end,
  },
}
