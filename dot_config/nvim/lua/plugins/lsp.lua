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

      vim.g.lsp_enabled = vim.g.lsp_enabled ~= false

      local available = {}
      for _, server in ipairs(mason_lspconfig.get_available_servers()) do
        available[server] = true
      end

      local ts_server = available.ts_ls and "ts_ls" or "tsserver"
      local servers = { "gopls", "graphql", "taplo", ts_server }
      local server_set = {}
      for _, server in ipairs(servers) do
        server_set[server] = true
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
      end

      mason_lspconfig.setup({
        ensure_installed = servers,
        automatic_installation = true,
      })

      for _, server in ipairs(servers) do
        vim.lsp.config(server, {
          capabilities = capabilities,
          on_attach = on_attach,
        })
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

      vim.api.nvim_create_user_command("LspEnable", enable_lsp, {})
      vim.api.nvim_create_user_command("LspDisable", disable_lsp, {})
      vim.api.nvim_create_user_command("LspToggle", function()
        if vim.g.lsp_enabled then
          disable_lsp()
        else
          enable_lsp()
        end
      end, {})
    end,
  },
}
