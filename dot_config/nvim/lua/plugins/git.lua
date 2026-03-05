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

      -- <leader>g で差分パネルを開く（gitui 風: working/staged 分離 + diff 表示）
      vim.keymap.set("n", "<leader>g", ":DiffviewOpen<CR>", { noremap = true, silent = true, desc = "Git差分パネルを開く" })
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

      -- lazygit をフローティングウィンドウで開く
      keymap("n", "<leader>lg", ":LazyGit<CR>", { noremap = true, silent = true, desc = "lazygit を開く" })
      -- 現在ファイルのリポジトリで lazygit を開く
      keymap("n", "<leader>lf", ":LazyGitCurrentFile<CR>", { noremap = true, silent = true, desc = "lazygit（現在ファイル）" })
    end,
  },
}
