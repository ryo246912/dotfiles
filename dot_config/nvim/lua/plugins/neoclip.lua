return {
  {
    "AckslD/nvim-neoclip.lua",
    dependencies = { "nvim-lua/plenary.nvim", "ibhagwan/fzf-lua" },
    keys = {
      { "<leader>y", function() require("neoclip.fzf")() end, desc = "ヤンク履歴選択" },
    },
    config = function()
      require("neoclip").setup()
    end,
  },
}
