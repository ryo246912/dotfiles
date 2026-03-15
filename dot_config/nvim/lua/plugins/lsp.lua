return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local mason_lspconfig = require("mason-lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local is_headless = #vim.api.nvim_list_uis() == 0

      vim.g.lsp_enabled = vim.g.lsp_enabled ~= false
      vim.g.inline_diagnostics_enabled = vim.g.inline_diagnostics_enabled ~= false

      local available = {}
      for _, server in ipairs(mason_lspconfig.get_available_servers()) do
        available[server] = true
      end

      local ts_server = available.ts_ls and "ts_ls" or "tsserver"
      local server_configs = {
        gopls = {},
        graphql = {
          filetypes = { "graphql", "graphqls", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                autoImportCompletions = true,
                autoSearchPaths = true,
                diagnosticMode = "workspace",
                extraPaths = { ".venv" },
                gotoDefinitionInStringLiteral = true,
                useLibraryCodeForTypes = true,
              },
            },
          },
        },
        taplo = {},
        terraformls = {
          filetypes = { "terraform", "terraform-vars", "hcl" },
        },
      }
      server_configs[ts_server] = {}

      local servers = vim.tbl_keys(server_configs)
      local server_set = {}
      for _, server in ipairs(servers) do
        server_set[server] = true
      end

      local function diagnostic_virtual_text()
        if not vim.g.inline_diagnostics_enabled then
          return false
        end

        return {
          spacing = 2,
          source = "if_many",
          format = function(diagnostic)
            local prefixes = {
              [vim.diagnostic.severity.ERROR] = "E",
              [vim.diagnostic.severity.WARN] = "W",
              [vim.diagnostic.severity.INFO] = "I",
              [vim.diagnostic.severity.HINT] = "H",
            }
            local message = diagnostic.message:gsub("%s+", " ")
            return string.format("%s %s", prefixes[diagnostic.severity] or "-", message)
          end,
        }
      end

      local function apply_diagnostic_config()
        vim.diagnostic.config({
          float = {
            border = "rounded",
            source = "if_many",
          },
          severity_sort = true,
          underline = true,
          update_in_insert = false,
          virtual_text = diagnostic_virtual_text(),
        })
      end

      apply_diagnostic_config()

      local function has_call_hierarchy(bufnr)
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
          if client.server_capabilities.callHierarchyProvider then
            return true
          end
        end
        return false
      end

      local function on_attach(client, bufnr)
        if not vim.g.lsp_enabled then
          vim.schedule(function()
            vim.lsp.stop_client(client.id, true)
          end)
          return
        end

        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>fd", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        vim.keymap.set("n", "<leader>ci", function()
          if has_call_hierarchy(bufnr) and type(vim.lsp.buf.incoming_calls) == "function" then
            vim.lsp.buf.incoming_calls()
            return
          end
          vim.notify("この LSP では incoming call hierarchy を利用できません。", vim.log.levels.INFO)
        end, opts)
        vim.keymap.set("n", "<leader>co", function()
          if has_call_hierarchy(bufnr) and type(vim.lsp.buf.outgoing_calls) == "function" then
            vim.lsp.buf.outgoing_calls()
            return
          end
          vim.notify("この LSP では outgoing call hierarchy を利用できません。", vim.log.levels.INFO)
        end, opts)

        if client.server_capabilities.documentHighlightProvider then
          local group = vim.api.nvim_create_augroup("LspDocumentHighlight" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "BufLeave", "CursorMoved", "CursorMovedI" }, {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end

      mason_lspconfig.setup({
        ensure_installed = is_headless and {} or servers,
        automatic_installation = not is_headless,
      })

      for _, server in ipairs(servers) do
        local config = vim.tbl_deep_extend("force", {
          capabilities = capabilities,
          on_attach = on_attach,
        }, server_configs[server] or {})
        vim.lsp.config(server, config)
      end

      if vim.g.lsp_enabled then
        for _, server in ipairs(servers) do
          pcall(vim.lsp.enable, server, true)
        end
      end

      local function enable_lsp()
        vim.g.lsp_enabled = true
        vim.diagnostic.enable(true)
        for _, server in ipairs(servers) do
          pcall(vim.lsp.enable, server, true)
        end
        pcall(vim.cmd, "LspStart")
        vim.notify("LSP を有効化しました", vim.log.levels.INFO)
      end

      local function disable_lsp()
        vim.g.lsp_enabled = false
        vim.diagnostic.enable(false)
        for _, server in ipairs(servers) do
          pcall(vim.lsp.enable, server, false)
        end
        for _, client in ipairs(vim.lsp.get_clients()) do
          if server_set[client.name] then
            vim.lsp.stop_client(client.id, true)
          end
        end
        vim.notify("LSP を無効化しました", vim.log.levels.INFO)
      end

      pcall(vim.api.nvim_del_user_command, "LspEnable")
      pcall(vim.api.nvim_del_user_command, "LspDisable")
      pcall(vim.api.nvim_del_user_command, "LspToggle")
      pcall(vim.api.nvim_del_user_command, "InlineDiagnosticsEnable")
      pcall(vim.api.nvim_del_user_command, "InlineDiagnosticsDisable")
      pcall(vim.api.nvim_del_user_command, "InlineDiagnosticsToggle")

      vim.api.nvim_create_user_command("LspEnable", enable_lsp, {})
      vim.api.nvim_create_user_command("LspDisable", disable_lsp, {})
      vim.api.nvim_create_user_command("LspToggle", function()
        if vim.g.lsp_enabled then
          disable_lsp()
        else
          enable_lsp()
        end
      end, {})

      vim.api.nvim_create_user_command("InlineDiagnosticsEnable", function()
        vim.g.inline_diagnostics_enabled = true
        apply_diagnostic_config()
        vim.notify("インライン診断表示を有効化しました", vim.log.levels.INFO)
      end, {})

      vim.api.nvim_create_user_command("InlineDiagnosticsDisable", function()
        vim.g.inline_diagnostics_enabled = false
        apply_diagnostic_config()
        vim.notify("インライン診断表示を無効化しました", vim.log.levels.INFO)
      end, {})

      vim.api.nvim_create_user_command("InlineDiagnosticsToggle", function()
        vim.g.inline_diagnostics_enabled = not vim.g.inline_diagnostics_enabled
        apply_diagnostic_config()
        if vim.g.inline_diagnostics_enabled then
          vim.notify("インライン診断表示を有効化しました", vim.log.levels.INFO)
        else
          vim.notify("インライン診断表示を無効化しました", vim.log.levels.INFO)
        end
      end, {})

      vim.keymap.set("n", "<leader>ud", "<Cmd>InlineDiagnosticsToggle<CR>", {
        noremap = true,
        silent = true,
        desc = "インライン診断表示切替",
      })
    end,
  },
}
