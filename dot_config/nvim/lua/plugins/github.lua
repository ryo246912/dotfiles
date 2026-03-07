return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    config = function()
      require("octo").setup({
        picker = "fzf-lua",
        default_remote = { "upstream", "origin" },
        -- GitHub Enterprise の場合は以下を設定
        -- github_hostname = "github.example.com",
      })

      local keymap = vim.keymap.set

      -- PR 操作
      keymap("n", "<leader>op", "<Cmd>Octo pr list<CR>",       { noremap = true, silent = true, desc = "PR一覧" })
      keymap("n", "<leader>oc", "<Cmd>Octo pr create<CR>",     { noremap = true, silent = true, desc = "PR作成" })
      keymap("n", "<leader>or", "<Cmd>Octo review start<CR>",  { noremap = true, silent = true, desc = "PRレビュー開始" })

      -- Issue 操作
      keymap("n", "<leader>oi", "<Cmd>Octo issue list<CR>",    { noremap = true, silent = true, desc = "Issue一覧" })
      keymap("n", "<leader>oI", "<Cmd>Octo issue create<CR>",  { noremap = true, silent = true, desc = "Issue作成" })
    end,
  },
}
