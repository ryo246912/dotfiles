return {
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
