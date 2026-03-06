return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        start_in_insert = true,
        persist_mode = true,
        direction = "float",
        float_opts = {
          border = "curved",
        },
      })

      local Terminal = require("toggleterm.terminal").Terminal
      local keymap = vim.keymap.set

      local function command_exists(cmd)
        return vim.fn.executable(cmd) == 1
      end

      local function in_git_repo()
        vim.fn.system("git rev-parse --is-inside-work-tree")
        return vim.v.shell_error == 0
      end

      local function toggle_terminal()
        vim.cmd("ToggleTerm")
      end

      local keifu = Terminal:new({
        cmd = "keifu",
        direction = "horizontal",
        size = 15,
        hidden = true,
        close_on_exit = false,
      })

      local filetree = Terminal:new({
        cmd = "ft",
        direction = "float",
        hidden = true,
        close_on_exit = false,
        float_opts = {
          border = "curved",
        },
      })

      local function toggle_keifu()
        if not command_exists("keifu") then
          vim.notify("keifu が見つかりません。`mise install` を実行してください。", vim.log.levels.WARN)
          return
        end
        if not in_git_repo() then
          vim.notify("keifu は Git リポジトリ配下で実行してください。", vim.log.levels.WARN)
          return
        end
        keifu:toggle()
      end

      local function toggle_filetree()
        if not command_exists("ft") then
          vim.notify("ft(filetree) が見つかりません。`mise install` を実行してください。", vim.log.levels.WARN)
          return
        end
        filetree:toggle()
      end

      keymap({ "n", "t" }, "<leader>t", toggle_terminal, { noremap = true, silent = true, desc = "ターミナル開閉" })
      keymap({ "n", "t" }, "<leader>gk", toggle_keifu, { noremap = true, silent = true, desc = "keifu を開閉" })
      keymap({ "n", "t" }, "<leader>E", toggle_filetree, { noremap = true, silent = true, desc = "filetree(ft) を開閉" })
    end,
  },
}
