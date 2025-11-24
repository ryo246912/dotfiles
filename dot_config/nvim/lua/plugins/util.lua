return {
  {
      'MeanderingProgrammer/render-markdown.nvim',
      dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
      ---@module 'render-markdown'
      ---@type render.md.UserConfig
      opts = {
        render_modes = true,
        heading = {
          width = "block",
          left_pad = 0,
          right_pad = 4,
          icons = {},
        },
        code = {
          width = "block",
        },
      },
  },
  {
    "rcarriga/nvim-notify",
    config = function()
      require("notify").setup({
        background_colour = "#000000",
      })
      vim.notify = require("notify")
    end,
  },
  -- {
  --   "m4xshen/hardtime.nvim",
  --   lazy = false,
  --   dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
  --   opts = {
  --     max_count = 10,
  --       disabled_keys = {
  --         ["<Up>"] = {},    -- 矢印キー(上)を許可
  --         ["<Down>"] = {},  -- 矢印キー(下)を許可
  --         ["<Left>"] = {},  -- 矢印キー(左)を許可
  --         ["<Right>"] = {}, -- 矢印キー(右)を許可
  --     }
  --   },
  -- },
  {
    "vim-jp/vimdoc-ja",
    lazy = true,
  },
}
