return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      {
        "<leader>gm",
        function()
          local function admin_merge(squash)
            local label = squash and "adminスカッシュマージ" or "adminマージ"
            local flags = squash and "--squash" or "--merge"
            vim.ui.select({ "はい", "いいえ" }, { prompt = label .. " しますか？" }, function(choice)
              if choice ~= "はい" then return end
              vim.system(
                { "gh", "pr", "merge", "--admin", flags },
                { text = true },
                function(result)
                  vim.schedule(function()
                    if result.code == 0 then
                      vim.notify(label .. " 完了", vim.log.levels.INFO)
                    else
                      vim.notify(label .. " 失敗: " .. (result.stderr or ""), vim.log.levels.ERROR)
                    end
                  end)
                end
              )
            end)
          end

          local function format_gh_datetime(value)
            if type(value) ~= "string" then return "-" end
            local year, month, day, hour, min, sec = value:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z$")
            if not year then return value end
            return string.format("%s/%s/%s %s:%s:%s", year, month, day, hour, min, sec)
          end

          local function truncate_display(value, width)
            value = tostring(value or "")
            local result = ""
            for i = 0, vim.fn.strchars(value) - 1 do
              local next_result = result .. vim.fn.strcharpart(value, i, 1)
              if vim.fn.strdisplaywidth(next_result) > width then break end
              result = next_result
            end
            return result
          end

          local function pad_display(value, width)
            value = tostring(value or "")
            return value .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(value), 0))
          end

          local function format_pr_rows(prs)
            local rows = vim.tbl_map(function(pr)
              local author = pr.author and pr.author.login or "-"
              return {
                tostring(pr.number),
                truncate_display(pr.title or "", 50),
                author,
                pr.state or "-",
                pr.isDraft and "◯" or "☓",
                format_gh_datetime(pr.updatedAt),
                format_gh_datetime(pr.createdAt),
                pr.headRefName or "-",
              }
            end, prs)

            local header = { "no", "title", "author", "state", "draft", "updatedAt", "createdAt", "branch" }
            local widths = vim.tbl_map(function(value) return vim.fn.strdisplaywidth(value) end, header)
            for _, row in ipairs(rows) do
              for idx, value in ipairs(row) do
                widths[idx] = math.max(widths[idx], vim.fn.strdisplaywidth(tostring(value)))
              end
            end

            local function format_row(row)
              local formatted = {}
              for idx, value in ipairs(row) do
                formatted[idx] = pad_display(value, widths[idx])
              end
              return table.concat(formatted, "  ")
            end

            return vim.tbl_map(format_row, rows), format_row(header)
          end

          local function checkout_and_open_pr()
            vim.system(
              {
                "gh",
                "pr",
                "list",
                "--search",
                "user-review-requested:@me",
                "--limit",
                "100",
                "--json",
                "number,title,author,state,isDraft,updatedAt,createdAt,headRefName",
              },
              { text = true },
              function(result)
                vim.schedule(function()
                  if result.code ~= 0 then
                    vim.notify("PR一覧の取得に失敗: " .. (result.stderr or ""), vim.log.levels.ERROR)
                    return
                  end

                  local ok, prs = pcall(vim.json.decode, result.stdout or "[]")
                  if not ok or type(prs) ~= "table" then
                    vim.notify("PR一覧の解析に失敗", vim.log.levels.ERROR)
                    return
                  end
                  if #prs == 0 then
                    vim.notify("レビュー依頼されたPRがありません", vim.log.levels.INFO)
                    return
                  end

                  local display, header = format_pr_rows(prs)

                  require("fzf-lua").fzf_exec(display, {
                    prompt = "PR checkout + open> ",
                    fzf_opts = {
                      ["--no-sort"] = true,
                      ["--header"] = header,
                    },
                    actions = {
                      ["default"] = function(sel)
                        if not sel or not sel[1] then return end
                        for idx, d in ipairs(display) do
                          if d == sel[1] then
                            local pr = prs[idx]
                            vim.system(
                              { "gh", "pr", "checkout", tostring(pr.number) },
                              { text = true },
                              function(checkout_result)
                                vim.schedule(function()
                                  if checkout_result.code ~= 0 then
                                    vim.notify("PR checkoutに失敗: " .. (checkout_result.stderr or ""), vim.log.levels.ERROR)
                                    return
                                  end
                                  vim.notify("PR checkout完了: #" .. pr.number, vim.log.levels.INFO)
                                  vim.cmd("Octo pr edit " .. pr.number)
                                end)
                              end
                            )
                            return
                          end
                        end
                      end,
                    },
                  })
                end)
              end
            )
          end

          local items = {
            { label = "PR一覧",                    cmd = "Octo pr list" },
            { label = "PRを開いてcheckout",        cmd = "gh pr checkout + Octo pr edit", fn = checkout_and_open_pr },
            { label = "PR作成",                    cmd = "Octo pr create" },
            { label = "今開いているPRをcheckout",  cmd = "Octo pr checkout" },
            { label = "PR差分を見る",              cmd = "Octo review diff" },
            { label = "チェックステータス",        cmd = "Octo pr checks" },
            { label = "PRをブラウザで開く",        cmd = "Octo pr browser" },
            { label = "コメント追加",              cmd = "Octo comment add" },
            { label = "レビュー開始",              cmd = "Octo review start" },
            { label = "レビュー送信（承認含む）",  cmd = "Octo review submit" },
            { label = "レビュアー追加",            cmd = "Octo reviewer add" },
            { label = "マージ",                    cmd = "gh pr merge --admin --merge",  fn = function() admin_merge(false) end },
            { label = "スカッシュマージ",          cmd = "gh pr merge --admin --squash", fn = function() admin_merge(true) end },
            { label = "PRをクローズ",              cmd = "Octo pr close" },
            { label = "URL をコピー",              cmd = "Octo pr url" },
            { label = "レビュー準備完了",          cmd = "Octo pr ready" },
            { label = "Issue一覧",                 cmd = "Octo issue list" },
          }
          local display = vim.tbl_map(function(i) return i.label .. "  (" .. i.cmd .. ")" end, items)
          require("fzf-lua").fzf_exec(display, {
            prompt = "Octo> ",
            actions = {
              ["default"] = function(sel)
                if not sel or not sel[1] then return end
                for idx, d in ipairs(display) do
                  if d == sel[1] then
                    local item = items[idx]
                    if item.fn then
                      item.fn()
                    else
                      vim.cmd(item.cmd)
                    end
                    return
                  end
                end
              end,
            },
          })
        end,
        mode = "n",
        silent = true,
        desc = "Octoコマンドメニュー",
      },
    },
    config = function()
      require("octo").setup({
        picker = "fzf-lua",
        default_remote = { "upstream", "origin" },
        mappings = {
          review_diff = {
            add_review_comment    = { lhs = "c", desc = "コメント追加", mode = { "n", "x" } },
            add_review_suggestion = { lhs = "s", desc = "サジェスト追加", mode = { "n", "x" } },
            submit_review         = { lhs = "S", desc = "レビュー送信" },
            goto_file             = { lhs = "O", desc = "ファイルを開く" },
            select_next_entry     = { lhs = "gl", desc = "次の変更ファイルへ移動" },
            select_prev_entry     = { lhs = "gh", desc = "前の変更ファイルへ移動" },
            close_review_tab      = { lhs = "q", desc = "diff viewを閉じる" },
          },
          review_thread = {
            add_reply      = { lhs = "r", desc = "返信追加" },
            delete_comment = { lhs = "d", desc = "コメント削除" },
          },
        },
      })

      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(args)
          local ok = pcall(vim.api.nvim_buf_get_var, args.buf, "octo_diff_props")
          if not ok then return end
          vim.keymap.set("n", "C", function()
            local panel = require("octo.reviews.file-panel")
            local before = vim.fn.line(".")
            panel.next_thread()
            if vim.fn.line(".") == before then
              vim.api.nvim_win_set_cursor(0, { 1, 0 })
              panel.next_thread()
            end
          end, { buffer = args.buf, silent = true, desc = "次のスレッドへ（ループ）" })
        end,
      })
    end,
  },
}
