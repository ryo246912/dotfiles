return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        delay = 500,
      })
    end,
  },
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },
  {
    "tpope/vim-surround",
  },
  {
    "easymotion/vim-easymotion",
  },
  {
    "simeji/winresizer",
  },
  {
    "bronson/vim-trailing-whitespace",
  },
  {
    "sheerun/vim-polyglot",
  },
  {
    "tpope/vim-commentary",
  },
}
