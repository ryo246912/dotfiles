return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      { "<leader>op", "<Cmd>Octo pr list<CR>",      mode = "n", silent = true, desc = "PR一覧" },
      { "<leader>oc", "<Cmd>Octo pr create<CR>",    mode = "n", silent = true, desc = "PR作成" },
      { "<leader>or", "<Cmd>Octo review start<CR>", mode = "n", silent = true, desc = "PRレビュー開始" },
      { "<leader>oi", "<Cmd>Octo issue list<CR>",   mode = "n", silent = true, desc = "Issue一覧" },
      { "<leader>oI", "<Cmd>Octo issue create<CR>", mode = "n", silent = true, desc = "Issue作成" },
    },
    config = function()
      require("octo").setup({
        picker = "fzf-lua",
        default_remote = { "upstream", "origin" },
        -- GitHub Enterprise の場合は以下を設定
        -- github_hostname = "github.example.com",
      })
    end,
  },
}
