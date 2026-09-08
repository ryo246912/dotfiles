return {
    "copilotlsp-nvim/copilot-lsp",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    opts = {
        -- Copilot LSPの設定
        filetypes = {
            yaml = true,
            markdown = true,
            help = false,
            gitcommit = true,
            gitrebase = false,
            ["."] = false,
        },
        -- サーバー設定
        server_opts_overrides = {
            settings = {
                advanced = {
                    listCount = 10, -- 候補数
                    inlineSuggestCount = 3, -- インライン候補数
                },
            },
        },
    },
    config = function(_, opts)
        require("copilot-lsp").setup(opts)

        -- NES (Native Editor Support) の設定
        vim.g.copilot_nes_debounce = 500
        vim.lsp.enable("copilot_ls")

        -- キーマップの設定
        -- TABキーでCopilot NESの提案を受け入れる
        vim.keymap.set("n", "<tab>", function()
            local bufnr = vim.api.nvim_get_current_buf()
            local state = vim.b[bufnr].nes_state
            if state then
                -- Try to jump to the start of the suggestion edit.
                -- If already at the start, then apply the pending suggestion and jump to the end of the edit.
                local _ = require("copilot-lsp.nes").walk_cursor_start_edit()
                    or (
                        require("copilot-lsp.nes").apply_pending_nes()
                        and require("copilot-lsp.nes").walk_cursor_end_edit()
                    )
                return nil
            else
                -- Resolving the terminal's inability to distinguish between `TAB` and `<C-i>` in normal mode
                return "<C-i>"
            end
        end, { desc = "Accept Copilot NES suggestion", expr = true })
        vim.keymap.set("i", "<Tab>", function()
            local bufnr = vim.api.nvim_get_current_buf()
            local state = vim.b[bufnr].nes_state
            if state then
                require("copilot-lsp.nes").apply_pending_nes()
                return ''
            else
                return '<Tab>'
            end
        end, { expr = true, desc = "Accept Copilot suggestion" })

        -- ESCキーで提案を拒否
        vim.keymap.set("n", "<esc>", function()
            local bufnr = vim.api.nvim_get_current_buf()
            local state = vim.b[bufnr].nes_state
            if state then
                vim.b[bufnr].nes_state = nil
            else
                vim.cmd("noh") -- 検索ハイライトをクリア
            end
        end, { desc = "Dismiss Copilot NES suggestion" })
        vim.keymap.set("i", "<esc>", function()
            local bufnr = vim.api.nvim_get_current_buf()
            local state = vim.b[bufnr].nes_state
            if state then
                vim.b[bufnr].nes_state = nil
            else
                return '<esc>' -- Fallback to normal Esc behavior
            end
        end, { expr = true, desc = "Dismiss Copilot suggestion" })

        -- 次の提案に移動
        vim.keymap.set("n", "]c", function()
            require("copilot-lsp.nes").walk_cursor_next_edit()
        end, { desc = "Next Copilot suggestion" })

        -- 前の提案に移動
        vim.keymap.set("n", "[c", function()
            require("copilot-lsp.nes").walk_cursor_prev_edit()
        end, { desc = "Previous Copilot suggestion" })
    end,
}
