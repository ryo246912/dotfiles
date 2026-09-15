return {
  {
    "hat0uma/csvview.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "ibhagwan/fzf-lua" },
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" },
    opts = {
      parser = {
        comments = { "#", "//" },
      },
      view = {
        display_mode = "border",
      },
      keymaps = {
        textobject_field_inner = { "if", mode = { "o", "x" } },
        textobject_field_outer = { "af", mode = { "o", "x" } },
        jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
        jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
        jump_next_row = { "<Enter>", mode = { "n", "v" } },
        jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
      },
    },
    config = function(_, opts)
      require("csvview").setup(opts)

      local function open_csv_menu()
        local items = {
          { label = "Toggle", cmd = "CsvViewToggle" },
          { label = "Enable", cmd = "CsvViewEnable" },
          { label = "Disable", cmd = "CsvViewDisable" },
          { label = "Info", cmd = "CsvViewInfo" },
        }
        local display = vim.tbl_map(function(item)
          return item.label .. "  (" .. item.cmd .. ")"
        end, items)

        require("fzf-lua").fzf_exec(display, {
          prompt = "CsvView> ",
          actions = {
            ["default"] = function(selected)
              if not selected or not selected[1] then
                return
              end
              for idx, value in ipairs(display) do
                if value == selected[1] then
                  vim.cmd(items[idx].cmd)
                  return
                end
              end
            end,
          },
        })
      end

      local function attach_csvview(bufnr)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd("CsvViewEnable")
            end)
          end
        end)

        vim.keymap.set("n", "<leader>cm", open_csv_menu, {
          buffer = bufnr,
          noremap = true,
          silent = true,
          desc = "CsvViewコマンドメニュー",
        })
      end

      local group = vim.api.nvim_create_augroup("CsvViewAuto", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "csv", "tsv" },
        callback = function(args)
          attach_csvview(args.buf)
        end,
      })

      if vim.tbl_contains({ "csv", "tsv" }, vim.bo.filetype) then
        attach_csvview(0)
      end
    end,
  },
}
