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
          local items = {
            { label = "PR一覧",               cmd = "Octo pr list" },
            { label = "PR作成",               cmd = "Octo pr create" },
            { label = "PR差分を見る",         cmd = "Octo review diff" },
            { label = "チェックステータス",   cmd = "Octo pr checks" },
            { label = "PRをブラウザで開く",   cmd = "Octo pr browser" },
            { label = "コメント追加",         cmd = "Octo comment add" },
            { label = "レビュー開始",         cmd = "Octo review start" },
            { label = "レビュー送信（承認含む）", cmd = "Octo review submit" },
            { label = "レビュアー追加",       cmd = "Octo reviewer add" },
            { label = "マージ",               cmd = "Octo pr merge" },
            { label = "スカッシュマージ",     cmd = "Octo pr merge squash" },
            { label = "PRをクローズ",         cmd = "Octo pr close" },
            { label = "URL をコピー",         cmd = "Octo pr url" },
            { label = "レビュー準備完了",     cmd = "Octo pr ready" },
            { label = "Issue一覧",            cmd = "Octo issue list" },
          }
          local display = vim.tbl_map(function(i) return i.label .. "  (" .. i.cmd .. ")" end, items)
          require("fzf-lua").fzf_exec(display, {
            prompt = "Octo> ",
            actions = {
              ["default"] = function(sel)
                if not sel or not sel[1] then return end
                for idx, d in ipairs(display) do
                  if d == sel[1] then
                    vim.cmd(items[idx].cmd)
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
            goto_file             = { lhs = "o", desc = "ファイルを開く" },
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
