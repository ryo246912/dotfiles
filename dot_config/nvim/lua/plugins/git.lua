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
            { "n", "<CR>", "<Cmd>lua require('diffview.actions').select_entry()<CR>",  { desc = "差分を開く" } },
            { "n", "O",    "<Cmd>lua require('diffview.actions').goto_file_edit()<CR>", { desc = "現在のファイルを開く" } },
            { "n", "s",      "<Cmd>lua require('diffview.actions').toggle_stage_entry()<CR>", { desc = "ステージ/アンステージ切替" } },
            { "n", "S",      "<Cmd>lua require('diffview.actions').stage_all()<CR>", { desc = "全てステージ" } },
            { "n", "U",      "<Cmd>lua require('diffview.actions').unstage_all()<CR>", { desc = "全てアンステージ" } },
            { "n", "q",      "<Cmd>DiffviewClose<CR>", { desc = "閉じる" } },
            { "n", "?",      "<Cmd>lua require('diffview.actions').help('file_panel')<CR>", { desc = "ヘルプ" } },
          },
          file_history_panel = {
            { "n", "O", "<Cmd>lua require('diffview.actions').goto_file_edit()<CR>", { desc = "現在のファイルを開く" } },
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "閉じる" } },
          },
          view = {
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "閉じる" } },
          },
        },
      })

      local git_utils = require("utils.git")
      local find_repos = git_utils.find_repos

      -- リポジトリを選択して cmd を実行（単一なら即実行、複数なら fzf-lua で選択）
      local function with_repo(cmd, fallback_cmd)
        local repos = find_repos()
        local function launch(repo)
          local prev_cwd = vim.fn.getcwd()
          vim.fn.chdir(repo)
          vim.cmd(cmd)
          vim.schedule(function() vim.fn.chdir(prev_cwd) end)
        end
        if #repos == 0 then
          vim.cmd(fallback_cmd or cmd)
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

      -- 複数リポジトリのコミット履歴をタブで開く
      local function open_file_history_multi()
        local repos = find_repos()
        local entries = repos
        require("fzf-lua").fzf_exec(entries, {
          prompt = "リポジトリ選択（Tab複数選択）> ",
          fzf_opts = { ["--multi"] = true },
          actions = {
            ["default"] = function(selected)
              if not selected or #selected == 0 then return end
              for _, repo in ipairs(selected) do
                vim.cmd("tabnew")
                vim.cmd("tcd " .. vim.fn.fnameescape(repo))
                vim.cmd("DiffviewFileHistory")
              end
            end,
          },
        })
      end

      vim.keymap.set("n", "<leader>gd", function() with_repo("DiffviewOpen") end,    { noremap = true, silent = true, desc = "Git差分パネル（複数リポジトリ対応）" })
      vim.keymap.set("n", "<leader>gl", open_file_history_multi,                      { noremap = true, silent = true, desc = "リポジトリ全体のコミット履歴（Tab複数選択・別タブ）" })
      vim.keymap.set("n", "<leader>gL", ":DiffviewFileHistory %<CR>",                { noremap = true, silent = true, desc = "現在ファイルのコミット履歴（diffview）" })

    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local function get_github_base_url(repo_dir, callback)
        vim.system({ "git", "remote", "get-url", "origin" }, { text = true, cwd = repo_dir }, function(r)
          if r.code ~= 0 then callback(nil) return end
          local raw = vim.trim(r.stdout or "")
          local base = raw
            :gsub("^git@github%.com:", "https://github.com/")
            :gsub("%.git$", "")
          if not base:match("^https://github%.com/") then
            callback(nil) return
          end
          callback(base)
        end)
      end

      local function get_repo_relative_path(repo_dir, filepath, callback)
        vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = repo_dir }, function(r)
          if r.code ~= 0 then callback(nil) return end
          local root = vim.trim(r.stdout or "")
          local rel = vim.fs.relpath(root, vim.fs.normalize(filepath))
          callback(rel)
        end)
      end

      local function get_default_branch(repo_dir, callback)
        vim.system(
          { "git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" },
          { text = true, cwd = repo_dir },
          function(r)
            if r.code == 0 then
              local branch = vim.trim(r.stdout or ""):gsub("^origin/", "")
              if branch ~= "" then
                callback(branch)
                return
              end
            end

            vim.system(
              { "gh", "repo", "view", "--json", "defaultBranchRef", "--jq", ".defaultBranchRef.name" },
              { text = true, cwd = repo_dir },
              function(gh_result)
                if gh_result.code ~= 0 then callback(nil) return end
                local branch = vim.trim(gh_result.stdout or "")
                callback(branch ~= "" and branch or nil)
              end
            )
          end
        )
      end

      local function encode_url_path(path)
        return path:gsub("[^%w%-%._~/]", function(char)
          return string.format("%%%02X", string.byte(char))
        end)
      end

      local function build_github_url(base, sha, rel_path, lnum)
        return string.format("%s/blob/%s/%s#L%d", base, sha, encode_url_path(rel_path), lnum)
      end

      local function github_url_action(action)
        local lnum     = vim.api.nvim_win_get_cursor(0)[1]
        local filename = vim.api.nvim_buf_get_name(0)
        if filename == "" then
          vim.notify("未保存のバッファには使用できません", vim.log.levels.WARN)
          return
        end
        local repo_dir = vim.fn.fnamemodify(filename, ":h")

        get_github_base_url(repo_dir, function(base)
          if not base then
            vim.schedule(function()
              vim.notify("GitHub リモートが見つかりません", vim.log.levels.WARN)
            end)
            return
          end
          get_repo_relative_path(repo_dir, filename, function(rel)
            if not rel then return end
            if action == "main" then
              get_default_branch(repo_dir, function(branch)
                if not branch then
                  vim.schedule(function()
                    vim.notify("既定ブランチを取得できません", vim.log.levels.WARN)
                  end)
                  return
                end
                local url = build_github_url(base, branch, rel, lnum)
                vim.schedule(function() vim.ui.open(url) end)
              end)
            else
              vim.system({ "git", "rev-parse", "HEAD" },
                { text = true, cwd = repo_dir },
                function(rv)
                  if rv.code ~= 0 then return end
                  local head_sha = vim.trim(rv.stdout or "")
                  local url = build_github_url(base, head_sha, rel, lnum)
                  vim.schedule(function()
                    if action == "copy" then
                      vim.fn.setreg("+", url)
                      vim.notify("コピーしました: " .. url, vim.log.levels.INFO)
                    else
                      vim.ui.open(url)
                    end
                  end)
                end)
            end
          end)
        end)
      end

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
          map("n", "<leader>gb", gs.blame, { desc = "Blameウィンドウをトグル" })

          -- コミット + PR 情報ポップアップ
          local function show_commit_with_pr()
            local lnum = vim.api.nvim_win_get_cursor(0)[1]
            local filename = vim.api.nvim_buf_get_name(bufnr)
            local repo_dir = vim.fn.fnamemodify(filename, ":h")

            vim.system(
              { "git", "-c", "core.quotePath=false", "blame", "-L", lnum .. "," .. lnum, "--porcelain", filename },
              { text = true, cwd = repo_dir },
              function(blame_result)
                if blame_result.code ~= 0 then
                  vim.schedule(function()
                    vim.notify("git blame 失敗: " .. (blame_result.stderr or ""), vim.log.levels.ERROR)
                  end)
                  return
                end

                local sha, blame_lnum = blame_result.stdout:match("^(%x+) (%d+)")
                local blame_filename = blame_result.stdout:match("\nfilename ([^\n]+)")
                blame_lnum = tonumber(blame_lnum) or lnum
                if not sha or sha:match("^0+$") then
                  vim.schedule(function()
                    vim.notify("コミット情報を取得できません（未コミットの行）", vim.log.levels.WARN)
                  end)
                  return
                end

                vim.system(
                  { "git", "show", "--format=%H%n%an%n%ai%n%s", "--no-patch", sha },
                  { text = true, cwd = repo_dir },
                  function(commit_result)
                    if commit_result.code ~= 0 then
                      vim.schedule(function()
                        vim.notify("git show 失敗: " .. (commit_result.stderr or ""), vim.log.levels.ERROR)
                      end)
                      return
                    end
                    local info = vim.split(commit_result.stdout or "", "\n")
                    local commit_sha = info[1] or sha
                    local author     = info[2] or "Unknown"
                    local date       = info[3] or ""
                    local subject    = info[4] or ""

                    vim.system(
                      { "gh", "pr", "list", "--search", sha, "--state", "merged",
                        "--json", "number,title,url", "--limit", "1" },
                      { text = true, cwd = repo_dir },
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
                              table.insert(display, "[o] PRをブラウザで開く")
                              table.insert(display, "[d] diffviewで開く")
                              table.insert(display, "[y] パーマネントリンクをコピー")
                              table.insert(display, "[b] ブラウザで開く（コミット）")
                              table.insert(display, "[B] ブラウザで開く（main）")
                              table.insert(display, "[q] 閉じる")
                            else
                              table.insert(display, "PR: 見つかりません")
                              table.insert(display, "")
                              table.insert(display, "[d] diffviewで開く")
                              table.insert(display, "[y] パーマネントリンクをコピー")
                              table.insert(display, "[b] ブラウザで開く（コミット）")
                              table.insert(display, "[B] ブラウザで開く（main）")
                              table.insert(display, "[q] 閉じる")
                            end
                          else
                            table.insert(display, "PR: 取得できません（gh CLI エラー）")
                            table.insert(display, "")
                            table.insert(display, "[d] diffviewで開く")
                            table.insert(display, "[y] パーマネントリンクをコピー")
                            table.insert(display, "[b] ブラウザで開く（コミット）")
                            table.insert(display, "[B] ブラウザで開く（main）")
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
                          vim.keymap.set("n", "d", function()
                            close()
                            vim.cmd("DiffviewOpen " .. commit_sha .. "^.." .. commit_sha)
                          end, { buffer = float_buf, nowait = true, desc = "diffviewでコミットを開く" })
                          vim.keymap.set("n", "y", function()
                            get_github_base_url(repo_dir, function(base)
                              if not base then
                                vim.schedule(function()
                                  vim.notify("GitHub リモートが見つかりません", vim.log.levels.WARN)
                                end)
                                return
                              end
                              local rel = blame_filename
                              if not rel then return end
                              local url = build_github_url(base, commit_sha, rel, blame_lnum)
                              vim.schedule(function()
                                vim.fn.setreg("+", url)
                                vim.notify("コピーしました: " .. url, vim.log.levels.INFO)
                              end)
                            end)
                          end, { buffer = float_buf, nowait = true, desc = "パーマネントリンクをコピー" })
                          vim.keymap.set("n", "b", function()
                            get_github_base_url(repo_dir, function(base)
                              if not base then return end
                              local rel = blame_filename
                              if not rel then return end
                              local url = build_github_url(base, commit_sha, rel, blame_lnum)
                              vim.schedule(function() vim.ui.open(url) end)
                            end)
                          end, { buffer = float_buf, nowait = true, desc = "ブラウザで開く（コミット）" })
                          vim.keymap.set("n", "B", function()
                            get_github_base_url(repo_dir, function(base)
                              if not base then return end
                              get_repo_relative_path(repo_dir, filename, function(rel)
                                if not rel then return end
                                get_default_branch(repo_dir, function(branch)
                                  if not branch then
                                    vim.schedule(function()
                                      vim.notify("既定ブランチを取得できません", vim.log.levels.WARN)
                                    end)
                                    return
                                  end
                                  local url = build_github_url(base, branch, rel, lnum)
                                  vim.schedule(function() vim.ui.open(url) end)
                                end)
                              end)
                            end)
                          end, { buffer = float_buf, nowait = true, desc = "ブラウザで開く（main ブランチ）" })
                        end)
                      end
                    )
                  end
                )
              end
            )
          end

          map("n", "<leader>gp", show_commit_with_pr, { desc = "コミット＋PR情報を表示" })

          -- 差分表示
          map("n", "<leader>hd", gs.diffthis, { desc = "working directoryとの差分" })
          map("n", "<leader>hD", function() gs.diffthis("~") end, { desc = "最後のコミットとの差分" })

          -- テキストオブジェクト（ハンク選択）
          map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "ハンクを選択" })
        end,
      })

      vim.keymap.set("n", "<leader>gy", function() github_url_action("copy") end,
        { noremap = true, silent = true, desc = "GitHub パーマネントリンクをコピー" })
      vim.keymap.set("n", "<leader>go", function() github_url_action("open") end,
        { noremap = true, silent = true, desc = "GitHub でファイルを開く（HEAD）" })
      vim.keymap.set("n", "<leader>gO", function() github_url_action("main") end,
        { noremap = true, silent = true, desc = "GitHub でファイルを開く（main）" })
    end,
  },
  {
    "tpope/vim-fugitive",
    config = function()
      local keymap = vim.keymap.set

      -- Git current branch
      keymap("n", "<leader>gB", ":Git branch --show-current<CR>", { noremap = true })
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local keymap = vim.keymap.set

      -- lazygitを指定したリポジトリをcwdとしてフローティングターミナルで開く
      local function open_lazygit(path)
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
        vim.fn.termopen({ "lazygit" }, {
          cwd = path,
          on_exit = function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end,
        })
        vim.cmd("startinsert")
      end

      local function open_lazygit_with_selection()
        local cwd = vim.fn.getcwd()
        local repos = require("utils.git").find_repos()
        if #repos == 0 then
          open_lazygit(cwd)
        elseif #repos == 1 then
          open_lazygit(repos[1])
        else
          require("fzf-lua").fzf_exec(repos, {
            prompt = "lazygit ディレクトリ選択> ",
            actions = {
              ["default"] = function(selected)
                if selected and selected[1] then open_lazygit(selected[1]) end
              end,
            },
          })
        end
      end

      keymap("n", "<leader>lg", open_lazygit_with_selection, { noremap = true, silent = true, desc = "lazygit を開く（ディレクトリ選択）" })
    end,
  },
}
