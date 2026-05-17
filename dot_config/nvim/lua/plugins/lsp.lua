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
      local function has_lspconfig(server)
        return #vim.api.nvim_get_runtime_file("lsp/" .. server .. ".lua", false) > 0
      end

      vim.g.lsp_enabled = vim.g.lsp_enabled ~= false
      vim.g.inline_diagnostics_enabled = vim.g.inline_diagnostics_enabled ~= false

      local ts_server = has_lspconfig("ts_ls") and "ts_ls" or "tsserver"
      local python_server = has_lspconfig("pyright") and "pyright" or (has_lspconfig("basedpyright") and "basedpyright" or nil)
      local servers = {
        gopls = {
          settings = {
            gopls = {
              completeUnimported = true,
              usePlaceholders = true,
              analyses = {
                unusedparams = true,
              },
            },
          },
        },
        graphql = {
          filetypes = {
            "graphql",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
          },
        },
        jsonls = {},
        taplo = {},
        terraformls = {},
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
            },
          },
        },
        [ts_server] = {},
      }

      if python_server then
        servers[python_server] = {
          settings = {
            python = {
              analysis = {
                autoImportCompletions = true,
                diagnosticMode = "workspace",
                gotoDefinitionInStringLiteral = true,
                indexing = true,
                typeCheckingMode = "basic",
                useLibraryCodeForTypes = true,
                extraPaths = { ".venv" },
              },
            },
          },
        }
      end

      if has_lspconfig("ruff") then
        servers.ruff = {}
      end

      local server_names = vim.tbl_keys(servers)
      table.sort(server_names)
      local server_set = {}
      for _, server in ipairs(server_names) do
        server_set[server] = true
      end

      local function format_diagnostic_message(diagnostic)
        local icons = {
          [vim.diagnostic.severity.ERROR] = "E",
          [vim.diagnostic.severity.WARN] = "W",
          [vim.diagnostic.severity.INFO] = "I",
          [vim.diagnostic.severity.HINT] = "H",
        }
        local message = (diagnostic.message or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return string.format("%s %s", icons[diagnostic.severity] or "-", message)
      end

      local function flatten_locations(result)
        local locations = {}
        for _, response in pairs(result or {}) do
          if response.result then
            if response.result.uri or response.result.targetUri then
              table.insert(locations, response.result)
            else
              vim.list_extend(locations, response.result)
            end
          end
        end
        return locations
      end

      local function show_locations(locations, offset_encoding, title)
        if vim.tbl_isempty(locations) then
          return false
        end

        if #locations == 1 then
          vim.lsp.util.show_document(locations[1], offset_encoding, { focus = true })
          return true
        end

        vim.fn.setqflist({}, " ", {
          title = title,
          items = vim.lsp.util.locations_to_items(locations, offset_encoding),
        })
        vim.cmd("botright copen")
        return true
      end

      local function graphql_root(bufnr)
        local path = vim.api.nvim_buf_get_name(bufnr)
        return vim.fs.root(path, {
          ".graphqlrc.yml",
          ".graphqlrc.yaml",
          ".graphqlrc.json",
          ".graphqlrc.js",
          ".graphqlrc.cjs",
          ".graphqlrc.ts",
          ".graphqlrc.toml",
          "graphql.config.js",
          "graphql.config.cjs",
          "graphql.config.ts",
          ".git",
        }) or vim.fs.dirname(path)
      end

      local function graphql_search(bufnr, mode)
        if vim.fn.executable("rg") ~= 1 then
          return false
        end

        local word = vim.fn.expand("<cword>")
        if word == nil or word == "" then
          return false
        end

        local root_dir = graphql_root(bufnr)
        local patterns = mode == "definition" and {
          "\\bfragment\\s+" .. word .. "\\b",
          "\\btype\\s+" .. word .. "\\b",
          "\\binput\\s+" .. word .. "\\b",
          "\\binterface\\s+" .. word .. "\\b",
          "\\benum\\s+" .. word .. "\\b",
          "\\bunion\\s+" .. word .. "\\b",
          "\\bscalar\\s+" .. word .. "\\b",
          "\\bquery\\s+" .. word .. "\\b",
          "\\bmutation\\s+" .. word .. "\\b",
          "\\bsubscription\\s+" .. word .. "\\b",
          "\\b" .. word .. "\\s*:",
        } or {
          "\\b" .. word .. "\\b",
        }

        local cmd = { "rg", "--vimgrep", "--glob", "*.graphql", "--glob", "*.graphqls", "--glob", "*.gql" }
        for _, pattern in ipairs(patterns) do
          table.insert(cmd, "-e")
          table.insert(cmd, pattern)
        end
        table.insert(cmd, root_dir)

        local result = vim.system(cmd, { cwd = root_dir, text = true }):wait()
        if result.code ~= 0 and (result.stdout == nil or result.stdout == "") then
          return false
        end

        local items = {}
        for line in vim.gsplit(result.stdout or "", "\n", { trimempty = true }) do
          local filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
          if filename and lnum and col then
            table.insert(items, {
              filename = filename,
              lnum = tonumber(lnum),
              col = tonumber(col),
              text = text,
            })
          end
        end

        if vim.tbl_isempty(items) then
          return false
        end

        vim.fn.setqflist({}, " ", {
          title = mode == "definition" and ("GraphQL definitions: " .. word) or ("GraphQL references: " .. word),
          items = items,
        })

        if #items == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(items[1].filename))
          vim.api.nvim_win_set_cursor(0, { items[1].lnum, math.max(items[1].col - 1, 0) })
        else
          vim.cmd("botright copen")
        end

        return true
      end

      local function apply_diagnostic_config()
        vim.diagnostic.config({
          underline = true,
          severity_sort = true,
          update_in_insert = true,
          virtual_text = vim.g.inline_diagnostics_enabled and {
            spacing = 2,
            source = "if_many",
            prefix = "",
            format = format_diagnostic_message,
          } or false,
          float = {
            border = "rounded",
            source = "if_many",
          },
        })
      end

      local function buffer_client(bufnr, names)
        for _, name in ipairs(names) do
          for _, attached in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            if attached.name == name then
              return attached
            end
          end
        end
        return nil
      end

      local function typescript_buffer(bufnr)
        return vim.tbl_contains({
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
        }, vim.bo[bufnr].filetype)
      end

      local function graphql_buffer(bufnr)
        return vim.bo[bufnr].filetype == "graphql"
      end

      local function on_attach(client, bufnr)
        if not vim.g.lsp_enabled then
          vim.schedule(function()
            vim.lsp.stop_client(client.id, true)
          end)
          return
        end

        if vim.b[bufnr].vscode_like_lsp_maps then
          return
        end

        local opts = { noremap = true, silent = true, buffer = bufnr }

        local function goto_definition()
          local ts_client = typescript_buffer(bufnr) and buffer_client(bufnr, { "ts_ls", "tsserver" }) or nil
          if ts_client then
            local params = vim.lsp.util.make_position_params(0, ts_client.offset_encoding)
            ts_client:exec_cmd({
              command = "_typescript.goToSourceDefinition",
              title = "Go to source definition",
              arguments = { params.textDocument.uri, params.position },
            }, { bufnr = bufnr }, function(err, result)
              if err then
                vim.notify("TypeScript source definition に失敗しました: " .. err.message, vim.log.levels.ERROR)
                return
              end
              if result and result[1] then
                vim.lsp.util.show_document(result[1], ts_client.offset_encoding, { focus = true })
                return
              end
              vim.lsp.buf.definition()
            end)
            return
          end

          local graphql_client = graphql_buffer(bufnr) and buffer_client(bufnr, { "graphql" }) or nil
          if graphql_client then
            local locations = {}
            if graphql_client:supports_method("textDocument/definition") then
              locations = flatten_locations(vim.lsp.buf_request_sync(
                bufnr,
                "textDocument/definition",
                vim.lsp.util.make_position_params(0, graphql_client.offset_encoding),
                1500
              ))
            end
            if show_locations(locations, graphql_client.offset_encoding, "GraphQL definitions") then
              return
            end
            if graphql_search(bufnr, "definition") then
              return
            end
            vim.notify("GraphQL definition が見つかりません", vim.log.levels.INFO)
            return
          end

          vim.lsp.buf.definition()
        end

        local function goto_references()
          local graphql_client = graphql_buffer(bufnr) and buffer_client(bufnr, { "graphql" }) or nil
          if graphql_client then
            local locations = {}
            if graphql_client:supports_method("textDocument/references") then
              local params = vim.lsp.util.make_position_params(0, graphql_client.offset_encoding)
              params.context = { includeDeclaration = true }
              locations = flatten_locations(vim.lsp.buf_request_sync(bufnr, "textDocument/references", params, 1500))
            end
            if show_locations(locations, graphql_client.offset_encoding, "GraphQL references") then
              return
            end
            if graphql_search(bufnr, "references") then
              return
            end
            vim.notify("GraphQL references が見つかりません", vim.log.levels.INFO)
            return
          end

          vim.lsp.buf.references()
        end

        vim.keymap.set("n", "gd", goto_definition, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gr", goto_references, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>fd", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        vim.b[bufnr].vscode_like_lsp_maps = true
      end

      mason_lspconfig.setup({
        ensure_installed = server_names,
        automatic_installation = true,
      })

      for _, server in ipairs(server_names) do
        vim.lsp.config(server, vim.tbl_deep_extend("force", {
          capabilities = capabilities,
          on_attach = on_attach,
        }, servers[server]))
      end

      apply_diagnostic_config()

      if vim.g.lsp_enabled then
        for _, server in ipairs(server_names) do
          pcall(vim.lsp.enable, server, true)
        end
      end

      local function enable_lsp()
        vim.g.lsp_enabled = true
        apply_diagnostic_config()
        vim.diagnostic.enable(true)
        for _, server in ipairs(server_names) do
          pcall(vim.lsp.enable, server, true)
        end
        pcall(vim.cmd, "LspStart")
        vim.notify("LSP を有効化しました", vim.log.levels.INFO)
      end

      local function disable_lsp()
        vim.g.lsp_enabled = false
        vim.diagnostic.enable(false)
        for _, server in ipairs(server_names) do
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
        vim.notify("inline diagnostics を有効化しました", vim.log.levels.INFO)
      end, {})
      vim.api.nvim_create_user_command("InlineDiagnosticsDisable", function()
        vim.g.inline_diagnostics_enabled = false
        apply_diagnostic_config()
        vim.notify("inline diagnostics を無効化しました", vim.log.levels.INFO)
      end, {})
      vim.api.nvim_create_user_command("InlineDiagnosticsToggle", function()
        vim.g.inline_diagnostics_enabled = not vim.g.inline_diagnostics_enabled
        apply_diagnostic_config()
        local status = vim.g.inline_diagnostics_enabled and "有効" or "無効"
        vim.notify("inline diagnostics を " .. status .. " にしました", vim.log.levels.INFO)
      end, {})

      vim.keymap.set("n", "<leader>xi", "<cmd>InlineDiagnosticsToggle<CR>", {
        noremap = true,
        silent = true,
        desc = "inline diagnostics を切り替え",
      })
    end,
  },
}
