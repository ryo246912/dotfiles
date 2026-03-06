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
            ["s"] = "open_vsplit",
            ["S"] = "open_split",
            ["t"] = "open_tabnew",
            ["P"] = { "toggle_preview", config = { use_float = true } },
            ["l"] = "open",
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
  {
    "nanotee/zoxide.vim",
    config = function()
      -- cdの際にdirectoryのスコアを増やす
      vim.g.zoxide_hook = "pwd"

      -- zoxideを起動
      vim.cmd("cnoremap zz :Zi<CR>")
    end,
  },
}
