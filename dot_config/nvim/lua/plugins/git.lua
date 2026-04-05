return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("diffview").setup({
        view = {
          default = {
            layout = "diff2_horizontal",
          },
        },
        file_panel = {
          listing_style = "tree",
          win_config = {
            position = "left",
            width = 35,
          },
        },
        keymaps = {
          file_panel = {
            { "n", "<CR>", "<Cmd>lua require('diffview.actions').select_entry()<CR>", { desc = "差分を開く" } },
            { "n", "s",    "<Cmd>lua require('diffview.actions').toggle_stage_entry()<CR>", { desc = "ステージ/アンステージ切替" } },
            { "n", "S",    "<Cmd>lua require('diffview.actions').stage_all()<CR>", { desc = "全てステージ" } },
            { "n", "U",    "<Cmd>lua require('diffview.actions').unstage_all()<CR>", { desc = "全てアンステージ" } },
            { "n", "q",    "<Cmd>DiffviewClose<CR>", { desc = "閉じる" } },
            { "n", "?",    "<Cmd>lua require('diffview.actions').help('file_panel')<CR>", { desc = "ヘルプ" } },
          },
          view = {
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "閉じる" } },
          },
        },
      })

      -- リポジトリを選択して DiffviewOpen
      local function open_diffview()
        local cwd = vim.fn.getcwd()
        local repos = {}

        -- .git がディレクトリ（通常リポジトリ）またはファイル（worktree）か確認
        local function is_git_root(dir)
          local git = dir .. "/.git"
          return vim.fn.isdirectory(git) == 1 or vim.fn.filereadable(git) == 1
        end

        if is_git_root(cwd) then
          table.insert(repos, cwd)
        end
        for _, p in ipairs(vim.fn.glob(cwd .. "/*/.git", false, true)) do
          local dir = vim.fn.fnamemodify(p, ":h")
          if is_git_root(dir) then table.insert(repos, dir) end
        end
        for _, p in ipairs(vim.fn.glob(cwd .. "/*/*/.git", false, true)) do
          local dir = vim.fn.fnamemodify(p, ":h")
          if is_git_root(dir) then table.insert(repos, dir) end
        end

        local function launch(repo)
          local prev_cwd = vim.fn.getcwd()
          vim.fn.chdir(repo)
          vim.cmd("DiffviewOpen")
          vim.schedule(function()
            vim.fn.chdir(prev_cwd)
          end)
        end

        if #repos == 0 then
          vim.cmd("DiffviewOpen")
        elseif #repos == 1 then
          launch(repos[1])
        else
          require("fzf-lua").fzf_exec(repos, {
            prompt = "リポジトリ選択> ",
            actions = {
              ["default"] = function(selected)
                if selected and selected[1] then launch(selected[1]) end
              end,
            },
          })
        end
      end

      vim.keymap.set("n", "<leader>g", open_diffview, { noremap = true, silent = true, desc = "Git差分パネル（複数リポジトリ対応）" })
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
          untracked    = { text = "┆" },
        },
        -- ステージ済み差分は太線で区別
        signs_staged = {
          add          = { text = "┃" },
          change       = { text = "┃" },
          delete       = { text = "=" },
          topdelete    = { text = "=" },
          changedelete = { text = "≈" },
          untracked    = { text = "╆" },
        },
        signs_staged_enable = true,

        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- ハンク間のジャンプ
          map("n", "]h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gs.nav_hunk("next")
            end
          end, { desc = "次のGit差分ハンクへ" })

          map("n", "[h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gs.nav_hunk("prev")
            end
          end, { desc = "前のGit差分ハンクへ" })

          -- 差分プレビュー
          map("n", "<leader>hp", gs.preview_hunk, { desc = "差分ハンクプレビュー" })
          map("n", "<leader>hP", gs.preview_hunk_inline, { desc = "差分ハンクインラインプレビュー" })

          -- ステージング操作
          map({ "n", "v" }, "<leader>hs", gs.stage_hunk, { desc = "ハンクをステージ" })
          map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "ハンクのステージを取り消し" })
          map("n", "<leader>hS", gs.stage_buffer, { desc = "バッファ全体をステージ" })

          -- リセット
          map({ "n", "v" }, "<leader>hr", gs.reset_hunk, { desc = "ハンクをリセット" })
          map("n", "<leader>hR", gs.reset_buffer, { desc = "バッファ全体をリセット" })

          -- Blame
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, { desc = "行のBlame表示" })
          map("n", "<leader>hB", gs.toggle_current_line_blame, { desc = "行Blame仮想テキスト切り替え" })

          -- 差分表示
          map("n", "<leader>hd", gs.diffthis, { desc = "working directoryとの差分" })
          map("n", "<leader>hD", function() gs.diffthis("~") end, { desc = "最後のコミットとの差分" })

          -- テキストオブジェクト（ハンク選択）
          map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "ハンクを選択" })
        end,
      })
    end,
  },
  {
    "linrongbin16/gitlinker.nvim",
    cmd = "GitLink",
    opts = {},
    keys = {
      { "<leader>gy", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Git の permalink をコピー" },
      { "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Git の permalink を開く" },
    },
  },
  {
    "tpope/vim-fugitive",
    config = function()
      local keymap = vim.keymap.set

      -- Gitステータス
      keymap("n", "<leader>gs", ":Git<CR>", { noremap = true })
      -- Git差分
      keymap("n", "<leader>gd", ":Git diff<CR>", { noremap = true })
      -- Git差分 (分割表示)
      keymap("n", "<leader>gv", ":Gdiffsplit<CR>", { noremap = true })
      -- Git show (最新コミットの詳細)
      keymap("n", "<leader>gh", ":Git show<CR>", { noremap = true })
      -- Git log -p
      keymap("n", "<leader>gl", ':Git log -p --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git log
      keymap("n", "<leader>gL", ':Git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git branch
      keymap("n", "<leader>gb", ":Git branch<CR>", { noremap = true })
      -- Git current branch
      keymap("n", "<leader>gB", ":Git branch --show-current<CR>", { noremap = true })
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local keymap = vim.keymap.set

      -- lazygit -p <path> でフローティングターミナルを開く（cd 不要）
      local function open_lazygit(path)
        local cmd = path and ("lazygit -p " .. vim.fn.shellescape(path)) or "lazygit"
        local buf = vim.api.nvim_create_buf(false, true)
        local width  = math.floor(vim.o.columns * 0.9)
        local height = math.floor(vim.o.lines   * 0.9)
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width    = width,
          height   = height,
          row      = math.floor((vim.o.lines   - height) / 2),
          col      = math.floor((vim.o.columns - width)  / 2),
          style    = "minimal",
          border   = "rounded",
        })
        vim.fn.termopen(cmd, {
          on_exit = function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end,
        })
        vim.cmd("startinsert")
      end

      -- lazygit をフローティングウィンドウで開く（cwd）
      keymap("n", "<leader>lg", ":LazyGit<CR>",            { noremap = true, silent = true, desc = "lazygit を開く" })
      -- 現在ファイルのリポジトリで lazygit を開く
      keymap("n", "<leader>lf", ":LazyGitCurrentFile<CR>", { noremap = true, silent = true, desc = "lazygit（現在ファイル）" })
    end,
  },
}
