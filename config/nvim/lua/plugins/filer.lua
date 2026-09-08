return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    lazy = false,
    config = function()
      local function open_with_picker(state)
        local ok, node = pcall(function()
          return state.tree:get_node()
        end)
        if not ok or not node then
          return
        end

        if node.type == "directory" then
          require("neo-tree.sources.filesystem.commands").open(state)
          return
        end

        local path = node:get_id()
        local commands = require("neo-tree.sources.common.commands")
        local options = {
          { label = "現在のウィンドウで開く", fn = commands.open },
          { label = "水平分割で開く", fn = commands.open_split },
          { label = "垂直分割で開く", fn = commands.open_vsplit },
          { label = "新規タブで開く", fn = commands.open_tabnew },
          {
            label = "システムのデフォルトアプリで開く",
            fn = function()
              local obj, err = vim.ui.open(path)
              if not obj then
                vim.notify("開けませんでした: " .. (err or "不明なエラー"), vim.log.levels.ERROR)
              end
            end,
          },
          {
            label = "コマンドを指定して開く...",
            fn = function()
              vim.ui.input({ prompt = "Open with command: " }, function(cmd)
                if not cmd or cmd:match("^%s*$") then
                  return
                end
                -- シェル経由で実行することで、cmd 内の引用符付き引数を維持しつつ path を安全にエスケープする
                local job_id = vim.fn.jobstart(cmd .. " " .. vim.fn.shellescape(path), { detach = true })
                if job_id <= 0 then
                  vim.notify("コマンドの起動に失敗しました: " .. cmd, vim.log.levels.ERROR)
                end
              end)
            end,
          },
        }

        vim.ui.select(options, {
          prompt = "Open with...",
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if choice then
            choice.fn(state)
          end
        end)
      end

      require("neo-tree").setup({
        close_if_last_window = false,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = false,

        default_component_configs = {
          indent = {
            indent_size = 2,
            with_markers = true,
          },
          icon = {
            folder_closed = "",
            folder_open = "",
            folder_empty = "",
            default = "",
          },
          git_status = {
            symbols = {
              -- working directory の変更（細い記号）
              added     = "",
              modified  = "",
              deleted   = "✖",
              renamed   = "󰁕",
              -- staging の状態（大文字で区別）
              untracked = "",
              ignored   = "",
              unstaged  = "󰄱",
              staged    = "",
              conflict  = "",
            },
          },
        },

        filesystem = {
          cwd_target = {
            -- サイドバーのルートをタブのtcdに追従させる
            sidebar = "tab",
            current = "window",
          },
          filtered_items = {
            -- 隠しファイルを表示
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
          follow_current_file = {
            -- 開いているファイルをツリーでハイライト
            enabled = true,
          },
          use_libuv_file_watcher = true,
        },

        window = {
          position = "left",
          width = 35,
          mappings = {
            ["<space>"] = "toggle_node",
            ["<cr>"] = "open",
            ["<C-h>"] = "open_split",
            ["<C-v>"] = "open_vsplit",
            ["<C-t>"] = "open_tabnew",
            ["s"] = "open_vsplit",
            ["S"] = "open_split",
            ["t"] = "open_tabnew",
            ["P"] = { "toggle_preview", config = { use_float = true } },
            ["l"] = "open",
            ["O"] = open_with_picker,
            ["h"] = "close_node",
            ["z"] = "close_all_nodes",
            ["a"] = "add",
            ["A"] = "add_directory",
            ["d"] = "delete",
            ["r"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
            ["R"] = "refresh",
            ["?"] = "show_help",
          },
        },

        buffers = {
          follow_current_file = {
            enabled = true,
          },
        },

        git_status = {
          window = {
            position = "left",
            width = 35,
            mappings = {
              ["<cr>"] = "open",
              ["l"] = "open",
              ["<C-h>"] = "open_split",
              ["<C-v>"] = "open_vsplit",
              ["<C-t>"] = "open_tabnew",
              ["s"] = "open_vsplit",
              ["S"] = "open_split",
              ["A"] = "git_add_all",
              ["ga"] = "git_add_file",
              ["gu"] = "git_unstage_file",
              ["gr"] = "git_revert_file",
              ["gc"] = "git_commit",
              ["q"] = "close_window",
              ["?"] = "show_help",
            },
          },
        },
      })

      local keymap = vim.keymap.set

      -- <leader>e でドロワーを開く/フォーカス（カレントファイルを表示）
      keymap("n", "<leader>e", ":Neotree filesystem reveal left<CR>", { noremap = true, silent = true, desc = "ファイルツリーを開く" })
      -- <leader>s でファイルツリーをトグル
      keymap("n", "<leader>s", ":Neotree toggle<CR>", { noremap = true, silent = true, desc = "ファイルツリーをトグル" })
      -- <leader>gt でGitステータスパネルを開く
      keymap("n", "<leader>gt", ":Neotree git_status<CR>", { noremap = true, silent = true, desc = "Git ステータスパネル" })
    end,
  },
}
