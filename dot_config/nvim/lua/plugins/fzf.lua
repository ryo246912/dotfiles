return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("fzf-lua").setup({
        -- ctrl-{h,v}で水平・垂直分割で開く
        actions = {
          files = {
            ["default"] = require("fzf-lua.actions").file_edit,
            ["ctrl-h"]  = require("fzf-lua.actions").file_split,
            ["ctrl-v"]  = require("fzf-lua.actions").file_vsplit,
            ["ctrl-t"]  = require("fzf-lua.actions").file_tabedit,
          },
          grep = {
            ["default"] = require("fzf-lua.actions").file_edit,
            ["ctrl-h"]  = require("fzf-lua.actions").file_split,
            ["ctrl-v"]  = require("fzf-lua.actions").file_vsplit,
            ["ctrl-t"]  = require("fzf-lua.actions").file_tabedit,
          },
        },
      })

      local fzf = require("fzf-lua")
      local keymap = vim.keymap.set
      local function select_tabpage()
        local tabs = vim.api.nvim_list_tabpages()
        local current_tab = vim.api.nvim_get_current_tabpage()
        local items = {}

        for _, tab in ipairs(tabs) do
          local wins = vim.api.nvim_tabpage_list_wins(tab)
          local win = wins[1]
          local buf = win and vim.api.nvim_win_get_buf(win) or nil
          local name = buf and vim.api.nvim_buf_get_name(buf) or ""
          local label = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
          local tabnr = vim.api.nvim_tabpage_get_number(tab)
          local current = tab == current_tab and "*" or " "
          table.insert(items, string.format("%d\t%s %s", tabnr, current, label))
        end

        fzf.fzf_exec(items, {
          prompt = "Tabs> ",
          actions = {
            ["default"] = function(selected)
              local choice = selected and selected[1] or nil
              local tabnr = choice and tonumber(choice:match("^(%d+)\t")) or nil
              if not tabnr then
                return
              end

              for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
                if vim.api.nvim_tabpage_get_number(tab) == tabnr and vim.api.nvim_tabpage_is_valid(tab) then
                  vim.api.nvim_set_current_tabpage(tab)
                  return
                end
              end
            end,
          },
        })
      end

      -- ファイル名で検索（VSCode Ctrl+P 相当）
      keymap("n", "<leader>p", fzf.files, { noremap = true, silent = true, desc = "ファイル名検索" })

      -- 現在のファイル内でワード検索 → マッチ位置にジャンプ
      keymap("n", "<leader>f", function()
        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file == "" then
          return
        end

        fzf.live_grep({
          cwd = vim.fn.getcwd(),
          search_paths = { current_file },
        })
      end, { noremap = true, silent = true, desc = "現在ファイル内検索" })

      -- pwd 以下をワード検索 → マッチ位置にジャンプ（VSCode Ctrl+Shift+F 相当）
      keymap("n", "<leader>F", function()
        fzf.live_grep({ cwd = vim.fn.getcwd() })
      end, { noremap = true, silent = true, desc = "リポジトリ全体検索" })

      -- カーソル下の単語で pwd 以下を Grep
      keymap("n", "<leader>P", function()
        fzf.grep_cword({ cwd = vim.fn.getcwd() })
      end, { noremap = true, silent = true, desc = "カーソル下の単語で検索" })

      -- バッファを表示
      keymap("n", "<leader>b", fzf.buffers,         { noremap = true, silent = true, desc = "バッファ検索" })
      -- コマンドを表示
      keymap("n", "<leader>C", fzf.commands,        { noremap = true, silent = true, desc = "コマンド検索" })
      -- ヘルプを表示
      keymap("n", "<leader>H", fzf.help_tags,       { noremap = true, silent = true, desc = "ヘルプ検索" })
      -- ファイル履歴を表示
      keymap("n", "<leader>r", fzf.oldfiles,        { noremap = true, silent = true, desc = "ファイル履歴" })
      -- コマンド履歴を表示
      keymap("n", "<leader>R", fzf.command_history, { noremap = true, silent = true, desc = "コマンド履歴" })
      -- タブを選択して切り替え
      keymap("n", "<leader>w", select_tabpage,      { noremap = true, silent = true, desc = "タブ選択" })
    end,
  },
}
