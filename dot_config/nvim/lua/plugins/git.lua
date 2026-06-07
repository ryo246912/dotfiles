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

      vim.keymap.set("n", "<leader>g",  open_diffview,                   { noremap = true, silent = true, desc = "Git差分パネル（複数リポジトリ対応）" })
      vim.keymap.set("n", "<leader>gH", ":DiffviewFileHistory<CR>",      { noremap = true, silent = true, desc = "リポジトリ全体のコミット履歴（diffview）" })
      vim.keymap.set("n", "<leader>gh", ":DiffviewFileHistory %<CR>",    { noremap = true, silent = true, desc = "現在ファイルのコミット履歴（diffview）" })
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 500,
          ignore_whitespace = true,
        },
        current_line_blame_formatter = "<author>, <author_time:%R> • <summary>",
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

          -- コミット + PR 情報ポップアップ
          local function show_commit_with_pr()
            local lnum = vim.api.nvim_win_get_cursor(0)[1]
            local filename = vim.api.nvim_buf_get_name(bufnr)

            vim.system(
              { "git", "blame", "-L", lnum .. "," .. lnum, "--porcelain", filename },
              { text = true },
              function(blame_result)
                if blame_result.code ~= 0 then
                  vim.schedule(function()
                    vim.notify("git blame 失敗: " .. (blame_result.stderr or ""), vim.log.levels.ERROR)
                  end)
                  return
                end

                local sha = blame_result.stdout:match("^(%x+)")
                if not sha or sha:match("^0+$") then
                  vim.schedule(function()
                    vim.notify("コミット情報を取得できません（未コミットの行）", vim.log.levels.WARN)
                  end)
                  return
                end

                vim.system(
                  { "git", "show", "--format=%H%n%an%n%ai%n%s", "--no-patch", sha },
                  { text = true },
                  function(commit_result)
                    local info = vim.split(commit_result.stdout or "", "\n")
                    local commit_sha = info[1] or sha
                    local author     = info[2] or "Unknown"
                    local date       = info[3] or ""
                    local subject    = info[4] or ""

                    vim.system(
                      { "gh", "pr", "list", "--search", sha, "--state", "merged",
                        "--json", "number,title,url", "--limit", "1" },
                      { text = true },
                      function(pr_result)
                        vim.schedule(function()
                          local display = {
                            "Commit: " .. commit_sha:sub(1, 8),
                            "Author: " .. author,
                            "Date:   " .. date,
                            "",
                            subject,
                            "",
                          }

                          local pr_url = nil
                          if pr_result.code == 0 and pr_result.stdout and pr_result.stdout ~= "" then
                            local ok, prs = pcall(vim.fn.json_decode, pr_result.stdout)
                            if ok and prs and #prs > 0 then
                              local pr = prs[1]
                              pr_url = pr.url
                              table.insert(display, string.format("PR: #%d - %s", pr.number, pr.title))
                              table.insert(display, "URL: " .. pr.url)
                              table.insert(display, "")
                              table.insert(display, "[o] ブラウザで開く  [q] 閉じる")
                            else
                              table.insert(display, "PR: 見つかりません")
                              table.insert(display, "")
                              table.insert(display, "[q] 閉じる")
                            end
                          else
                            table.insert(display, "PR: 取得できません（gh CLI エラー）")
                            table.insert(display, "")
                            table.insert(display, "[q] 閉じる")
                          end

                          local max_w = 0
                          for _, line in ipairs(display) do
                            max_w = math.max(max_w, vim.fn.strdisplaywidth(line))
                          end
                          local width  = math.max(50, math.min(max_w + 4, vim.o.columns - 4))
                          local height = #display

                          local float_buf = vim.api.nvim_create_buf(false, true)
                          vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, display)
                          vim.bo[float_buf].modifiable = false

                          local float_win = vim.api.nvim_open_win(float_buf, true, {
                            relative = "cursor",
                            row      = 1,
                            col      = 0,
                            width    = width,
                            height   = height,
                            style    = "minimal",
                            border   = "rounded",
                            title    = " Commit Info ",
                            title_pos = "center",
                          })

                          local close = function()
                            if vim.api.nvim_win_is_valid(float_win) then
                              vim.api.nvim_win_close(float_win, true)
                            end
                          end
                          vim.keymap.set("n", "q",     close, { buffer = float_buf, nowait = true })
                          vim.keymap.set("n", "<Esc>", close, { buffer = float_buf, nowait = true })
                          if pr_url then
                            vim.keymap.set("n", "o", function()
                              vim.ui.open(pr_url)
                            end, { buffer = float_buf, nowait = true, desc = "PRをブラウザで開く" })
                          end
                        end)
                      end
                    )
                  end
                )
              end
            )
          end

          map("n", "<leader>hm", show_commit_with_pr, { desc = "コミット＋PR情報を表示" })

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
      -- Git show (最新コミットの詳細) ※ <leader>gh は diffview に移管
      keymap("n", "<leader>gS", ":Git show<CR>", { noremap = true, desc = "Git show（最新コミット詳細）" })
      -- Git log -p
      keymap("n", "<leader>gl", ':Git log -p --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git log
      keymap("n", "<leader>gL", ':Git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %Cblue[%cn]" --date=format:"%Y/%m/%d %H:%M:%S"<CR>', { noremap = true })
      -- Git branch
      keymap("n", "<leader>gb", ":Git branch<CR>", { noremap = true })
      -- Git current branch
      keymap("n", "<leader>gB", ":Git branch --show-current<CR>", { noremap = true })
      -- コミットログ（fzf-lua + diffview）
      keymap("n", "<leader>gc", function()
        require("fzf-lua").git_commits({
          actions = {
            ["default"] = function(selected)
              if not selected or not selected[1] then return end
              local commit = selected[1]:match("^(%x+)")
              if commit then
                vim.cmd("DiffviewOpen " .. commit .. "^.." .. commit)
              end
            end,
          },
        })
      end, { noremap = true, silent = true, desc = "Gitコミットログ（fzf-lua）" })
      -- 現在ファイルのコミットログ（fzf-lua）
      keymap("n", "<leader>gC", function()
        require("fzf-lua").git_bcommits()
      end, { noremap = true, silent = true, desc = "現在ファイルのGitコミットログ（fzf-lua）" })
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
