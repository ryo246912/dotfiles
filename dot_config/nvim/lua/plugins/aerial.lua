return {
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>o", "<cmd>AerialToggle<CR>", desc = "Toggle Aerial" },
    },
    config = function()
      require("aerial").setup({
        layout = {
          default_direction = "right",
        },
      })
    end,
  },
}
