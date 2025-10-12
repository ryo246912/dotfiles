return {
  {
    "jiangmiao/auto-pairs",
    config = function()
      -- auto-pairsの削除を無効
      vim.g.AutoPairsMapBS = 0
      -- auto-pairsのスペースを無効
      vim.g.AutoPairsMapSpace = 0
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
