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
        },
      })

      local fzf = require("fzf-lua")
      local keymap = vim.keymap.set

      local function command_abbrev(lhs, command)
        vim.cmd(string.format(
          [[cabbr <expr> %s getcmdtype() ==# ':' && getcmdline() ==# %s ? "\<Cmd>%s\<CR>" : %s]],
          lhs,
          vim.fn.string(lhs),
          command,
          vim.fn.string(lhs)
        ))
      end

      local function change_tab_directory(dir)
        local ok, err = pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(dir))
        if not ok then
          vim.notify("ディレクトリの移動に失敗しました: " .. err, vim.log.levels.ERROR)
          return
        end

        local has_neo_tree, neo_tree = pcall(require, "neo-tree.command")
        if has_neo_tree then
          neo_tree.execute({ action = "show", source = "filesystem", position = "left", dir = dir })
        end
      end

      local function select_tabpage()
        local tabs = vim.api.nvim_list_tabpages()
        local current_tab = vim.api.nvim_get_current_tabpage()
        local items = {}

        for _, tab in ipairs(tabs) do
          local tabnr = vim.api.nvim_tabpage_get_number(tab)
          local cwd = vim.fn.getcwd(-1, tabnr)
          local parent = vim.fn.fnamemodify(cwd, ":h:t")
          local dirname = vim.fn.fnamemodify(cwd, ":t")
          local display = (parent ~= "" and parent ~= ".") and (parent .. "/" .. dirname) or dirname
          if display == "" then display = cwd end
          local current = tab == current_tab and "*" or " "
          table.insert(items, string.format("%d\t%s %s", tabnr, current, display))
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
      keymap("n", "<leader>b", fzf.buffers, { noremap = true, silent = true, desc = "バッファ検索" })
      -- コマンドを表示
      keymap("n", "<leader>c", fzf.commands, { noremap = true, silent = true, desc = "コマンド検索" })
      -- ヘルプを表示
      keymap("n", "<leader>?", fzf.help_tags, { noremap = true, silent = true, desc = "ヘルプ検索" })
      -- ファイル履歴を表示
      keymap("n", "<leader>r", fzf.oldfiles, { noremap = true, silent = true, desc = "ファイル履歴" })
      -- コマンド履歴を表示
      keymap("n", "<leader>R", fzf.command_history, { noremap = true, silent = true, desc = "コマンド履歴" })
      -- タブを選択して切り替え
      keymap("n", "<leader>w", select_tabpage, { noremap = true, silent = true, desc = "タブ選択" })

      -- zoxideでディレクトリ選択後、現在タブのみtcdで移動
      -- zoxide query --list で純粋なパス一覧を取得して fzf_exec に渡す
      local function zoxide_tcd()
        fzf.fzf_exec("zoxide query --list", {
          prompt = "Zoxide> ",
          actions = {
            ["default"] = function(selected)
              if not selected or not selected[1] then return end
              local dir = vim.trim(selected[1])
              if dir == "" then return end
              change_tab_directory(dir)
            end,
          },
        })
      end

      -- :zz で zoxide を起動（タブローカルtcd版）
      vim.api.nvim_create_user_command("Zz", zoxide_tcd, {})
      command_abbrev("zz", "Zz")

      -- 現在ディレクトリ配下のサブディレクトリをinteractiveに選択してtcd
      local function local_tcd()
        local cwd = vim.fn.getcwd()
        local dirs = {
          { path = cwd, depth = 0 },
        }

        for name, type in vim.fs.dir(cwd, { depth = 2 }) do
          local in_git_dir = name == ".git" or name:match("^%.git/") or name:match("/%.git/")
          if type == "directory" and not in_git_dir then
            local depth = select(2, name:gsub("/", "")) + 1
            table.insert(dirs, { path = vim.fs.joinpath(cwd, name), depth = depth })
          end
        end

        table.sort(dirs, function(a, b)
          if a.depth ~= b.depth then
            return a.depth < b.depth
          end

          return a.path < b.path
        end)

        local items = vim.tbl_map(function(dir)
          return dir.path
        end, dirs)

        fzf.fzf_exec(items, {
          prompt = "LocalDir> ",
          actions = {
            ["default"] = function(selected)
              if not selected or not selected[1] then return end
              local dir = vim.trim(selected[1])
              if dir == "" then return end
              change_tab_directory(dir)
            end,
          },
        })
      end

      -- :zd でローカルディレクトリ選択
      vim.api.nvim_create_user_command("Zd", local_tcd, {})
      command_abbrev("zd", "Zd")
    end,
  },
}
