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
      require("core.file_actions").setup()

      local Terminal = require("toggleterm.terminal").Terminal
      local keymap = vim.keymap.set
      local terminal_history_path = vim.fn.stdpath("state") .. "/terminal_command_history"
      local max_history = 30
      local preset_commands = {
        "chezmoi apply --interactive",
      }

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

      local function load_command_history()
        if vim.fn.filereadable(terminal_history_path) == 0 then
          return {}
        end
        return vim.fn.readfile(terminal_history_path)
      end

      local function save_command_history(cmd)
        local history = load_command_history()
        local next_history = { cmd }
        for _, item in ipairs(history) do
          if item ~= cmd and #next_history < max_history then
            table.insert(next_history, item)
          end
        end
        vim.fn.writefile(next_history, terminal_history_path)
      end

      local function run_popup_command(cmd)
        if not cmd or cmd == "" then
          return
        end

        save_command_history(cmd)
        Terminal:new({
          cmd = cmd,
          direction = "float",
          hidden = true,
          close_on_exit = false,
          float_opts = {
            border = "curved",
          },
        }):toggle()
      end

      local function open_popup_command_picker()
        local history = load_command_history()
        local choices = {}
        local values = {}

        for _, cmd in ipairs(preset_commands) do
          table.insert(choices, "[Preset] " .. cmd)
          table.insert(values, cmd)
        end
        for _, cmd in ipairs(history) do
          table.insert(choices, "[History] " .. cmd)
          table.insert(values, cmd)
        end
        table.insert(choices, "[Custom] コマンド入力")
        table.insert(values, "__custom__")

        vim.ui.select(choices, { prompt = "実行するコマンドを選択" }, function(_, idx)
          local selected = idx and values[idx] or nil
          if not selected then
            return
          end
          if selected == "__custom__" then
            vim.ui.input({ prompt = "Command> " }, function(input)
              run_popup_command(input)
            end)
            return
          end
          run_popup_command(selected)
        end)
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
      keymap("n", "<leader>cp", function() run_popup_command("chezmoi apply --interactive") end, { noremap = true, silent = true, desc = "chezmoi apply --interactive" })
      keymap("n", "<leader>C", open_popup_command_picker, { noremap = true, silent = true, desc = "コマンドを選んでポップアップ実行" })
      keymap({ "n", "t" }, "<leader>gk", toggle_keifu, { noremap = true, silent = true, desc = "keifu を開閉" })
      keymap({ "n", "t" }, "<leader>E", toggle_filetree, { noremap = true, silent = true, desc = "filetree(ft) を開閉" })
    end,
  },
}
