local M = {}

local state = {
  setup_done = false,
  formatting_buffers = {},
}

local function joinpath(...)
  return table.concat(vim.tbl_flatten({ ... }), "/")
end

local function buf_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end
  return vim.fs.normalize(path)
end

local function buf_is_file(bufnr)
  return vim.bo[bufnr].buftype == "" and buf_path(bufnr) ~= nil
end

local function read_json(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if ok then
    return decoded
  end
  return nil
end

local function has_file(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function relpath(root, path)
  if not root then
    return path
  end

  local relative = vim.fs.relpath(root, path)
  if relative == nil or relative == "" then
    return path
  end
  return relative
end

local function root(path, markers)
  local ok, result = pcall(vim.fs.root, path, markers)
  if ok then
    return result
  end
  return nil
end

local function executable(path)
  return path ~= nil and vim.fn.executable(path) == 1
end

local function resolve_binary(root_dir, names)
  local mason_bin = joinpath(vim.fn.stdpath("data"), "mason", "bin")

  for _, name in ipairs(names) do
    local candidates = {}

    if root_dir then
      table.insert(candidates, joinpath(root_dir, "node_modules", ".bin", name))
      table.insert(candidates, joinpath(root_dir, ".venv", "bin", name))
    end

    table.insert(candidates, joinpath(mason_bin, name))
    table.insert(candidates, name)

    for _, candidate in ipairs(candidates) do
      if executable(candidate) then
        return candidate
      end
    end
  end

  return nil
end

local function shell_join(parts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, parts), " ")
end

local function current_context(bufnr)
  local path = buf_path(bufnr)
  local dir = path and vim.fs.dirname(path) or vim.loop.cwd()
  local git_root = path and root(path, { ".git" }) or vim.loop.cwd()
  local node_root = path and root(path, { "package.json", "pnpm-lock.yaml", "bun.lock", "bun.lockb", "yarn.lock", "package-lock.json" }) or nil
  local python_root = path and root(path, { "pyproject.toml", "uv.lock", "requirements.txt", ".venv", "setup.py" }) or nil
  local go_root = path and root(path, { "go.mod" }) or nil

  return {
    bufnr = bufnr,
    path = path,
    dir = dir,
    filetype = vim.bo[bufnr].filetype,
    git_root = git_root,
    node_root = node_root,
    python_root = python_root,
    go_root = go_root,
    project_root = node_root or python_root or go_root or git_root or dir,
  }
end

local function package_manager(node_root)
  if node_root == nil then
    return nil
  end

  if has_file(joinpath(node_root, "pnpm-lock.yaml")) then
    return "pnpm"
  end
  if has_file(joinpath(node_root, "bun.lock")) or has_file(joinpath(node_root, "bun.lockb")) then
    return "bun"
  end
  if has_file(joinpath(node_root, "yarn.lock")) then
    return "yarn"
  end
  return "npm"
end

local function package_script(node_root, name)
  if node_root == nil then
    return false
  end

  local package_json = read_json(joinpath(node_root, "package.json"))
  return package_json ~= nil and package_json.scripts ~= nil and package_json.scripts[name] ~= nil
end

local function lsp_format_client(bufnr, preferred_names)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method("textDocument/formatting") then
      if preferred_names == nil or vim.tbl_contains(preferred_names, client.name) then
        return client
      end
    end
  end
  return nil
end

local function resolve_formatter(ctx)
  if ctx.path == nil then
    return nil
  end

  local ft = ctx.filetype

  if vim.tbl_contains({
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "yaml",
    "graphql",
  }, ft) then
    local prettier = resolve_binary(ctx.node_root or ctx.project_root, { "prettier" })
    if prettier then
      return {
        kind = "cli",
        label = "Prettier で format",
        cmd = prettier,
        args = { "--write", ctx.path },
        cwd = ctx.node_root or ctx.project_root or ctx.dir,
      }
    end
  end

  if ft == "python" then
    local ruff = resolve_binary(ctx.python_root or ctx.project_root, { "ruff" })
    if ruff then
      return {
        kind = "cli",
        label = "ruff format",
        cmd = ruff,
        args = { "format", ctx.path },
        cwd = ctx.python_root or ctx.project_root or ctx.dir,
      }
    end
  end

  if ft == "toml" then
    local taplo = resolve_binary(ctx.project_root, { "taplo" })
    if taplo then
      return {
        kind = "cli",
        label = "taplo format",
        cmd = taplo,
        args = { "format", ctx.path },
        cwd = ctx.project_root or ctx.dir,
      }
    end
  end

  if ft == "terraform" or ft == "terraform-vars" then
    local terraform = resolve_binary(ctx.project_root, { "terraform" })
    if terraform then
      return {
        kind = "cli",
        label = "terraform fmt",
        cmd = terraform,
        args = { "fmt", ctx.path },
        cwd = ctx.dir,
      }
    end
  end

  if ft == "go" then
    local gofmt = resolve_binary(ctx.go_root or ctx.project_root, { "gofmt" })
    if gofmt then
      return {
        kind = "cli",
        label = "gofmt -w",
        cmd = gofmt,
        args = { "-w", ctx.path },
        cwd = ctx.go_root or ctx.project_root or ctx.dir,
      }
    end
  end

  local preferred = nil
  if ft == "python" then
    preferred = { "ruff" }
  elseif ft == "javascript" or ft == "javascriptreact" or ft == "typescript" or ft == "typescriptreact" then
    preferred = { "ts_ls", "tsserver", "vtsls" }
  end

  local client = lsp_format_client(ctx.bufnr, preferred)
  if client ~= nil then
    return {
      kind = "lsp",
      label = "LSP format",
      client_name = client.name,
    }
  end

  return nil
end

local function run_cli_formatter(ctx, formatter, opts)
  opts = opts or {}
  local previous_state = state.formatting_buffers[ctx.bufnr]
  state.formatting_buffers[ctx.bufnr] = true

  if not opts.from_save then
    vim.api.nvim_buf_call(ctx.bufnr, function()
      vim.cmd("silent update")
    end)
  end

  local result = vim.system(vim.list_extend({ formatter.cmd }, formatter.args or {}), {
    cwd = formatter.cwd,
    text = true,
  }):wait()

  if result.code ~= 0 then
    local stderr = (result.stderr or result.stdout or ""):gsub("%s+$", "")
    state.formatting_buffers[ctx.bufnr] = previous_state
    vim.notify(("format に失敗しました: %s"):format(stderr), vim.log.levels.ERROR)
    return false
  end

  if vim.api.nvim_buf_is_valid(ctx.bufnr) then
    vim.api.nvim_buf_call(ctx.bufnr, function()
      vim.cmd("silent noautocmd edit")
    end)
  end

  if not opts.silent then
    vim.notify(formatter.label .. " を実行しました", vim.log.levels.INFO)
  end
  state.formatting_buffers[ctx.bufnr] = previous_state
  return true
end

local function run_lsp_formatter(ctx, formatter, opts)
  opts = opts or {}

  local ok, err = pcall(vim.lsp.buf.format, {
    bufnr = ctx.bufnr,
    async = false,
    timeout_ms = 3000,
    filter = function(client)
      return formatter.client_name == nil or client.name == formatter.client_name
    end,
  })

  if not ok then
    vim.notify(("LSP format に失敗しました: %s"):format(err), vim.log.levels.ERROR)
    return false
  end

  if not opts.silent then
    vim.notify(formatter.label .. " を実行しました", vim.log.levels.INFO)
  end
  return true
end

function M.format_buffer(opts)
  opts = opts or {}
  local bufnr = opts.buf or vim.api.nvim_get_current_buf()

  if not buf_is_file(bufnr) then
    vim.notify("保存済みファイルで実行してください", vim.log.levels.WARN)
    return false
  end

  local ctx = current_context(bufnr)
  local formatter = resolve_formatter(ctx)
  if formatter == nil then
    vim.notify("利用できる formatter が見つかりません", vim.log.levels.WARN)
    return false
  end

  if formatter.kind == "cli" then
    return run_cli_formatter(ctx, formatter, opts)
  end
  return run_lsp_formatter(ctx, formatter, opts)
end

local function add_action(actions, action)
  table.insert(actions, action)
end

local function add_shell_action(actions, label, parts, cwd)
  add_action(actions, {
    label = label,
    run = function()
      local ok, terminal = pcall(require, "toggleterm.terminal")
      if not ok then
        vim.notify("toggleterm.nvim の読み込みに失敗しました", vim.log.levels.ERROR)
        return
      end

      terminal.Terminal:new({
        cmd = shell_join(parts),
        cwd = cwd,
        direction = "float",
        hidden = true,
        close_on_exit = false,
        float_opts = {
          border = "curved",
        },
      }):toggle()
    end,
  })
end

function M.available_actions(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ctx = current_context(bufnr)
  local actions = {}
  local formatter = resolve_formatter(ctx)

  if formatter ~= nil then
    add_action(actions, {
      label = formatter.label,
      run = function()
        M.format_buffer({ buf = bufnr })
      end,
    })
  end

  if ctx.node_root ~= nil and ctx.path ~= nil then
    local relative_file = relpath(ctx.node_root, ctx.path)
    local pm = package_manager(ctx.node_root)
    local eslint = resolve_binary(ctx.node_root, { "eslint" })
    local vitest = resolve_binary(ctx.node_root, { "vitest" })
    local jest = resolve_binary(ctx.node_root, { "jest" })

    if eslint then
      add_shell_action(actions, "eslint --fix", { eslint, "--fix", relative_file }, ctx.node_root)
    elseif package_script(ctx.node_root, "lint") and pm ~= nil then
      if pm == "pnpm" then
        add_shell_action(actions, "pnpm lint", { "pnpm", "lint", "--", relative_file }, ctx.node_root)
      elseif pm == "bun" then
        add_shell_action(actions, "bun run lint", { "bun", "run", "lint", "--", relative_file }, ctx.node_root)
      elseif pm == "yarn" then
        add_shell_action(actions, "yarn lint", { "yarn", "lint", relative_file }, ctx.node_root)
      else
        add_shell_action(actions, "npm run lint", { "npm", "run", "lint", "--", relative_file }, ctx.node_root)
      end
    end

    if vitest then
      add_shell_action(actions, "vitest run", { vitest, "run", relative_file }, ctx.node_root)
    elseif jest then
      add_shell_action(actions, "jest", { jest, relative_file }, ctx.node_root)
    elseif package_script(ctx.node_root, "test") and pm ~= nil then
      if pm == "pnpm" then
        add_shell_action(actions, "pnpm test", { "pnpm", "test", "--", relative_file }, ctx.node_root)
      elseif pm == "bun" then
        add_shell_action(actions, "bun run test", { "bun", "run", "test", "--", relative_file }, ctx.node_root)
      elseif pm == "yarn" then
        add_shell_action(actions, "yarn test", { "yarn", "test", relative_file }, ctx.node_root)
      else
        add_shell_action(actions, "npm run test", { "npm", "run", "test", "--", relative_file }, ctx.node_root)
      end
    end
  end

  if ctx.filetype == "python" and ctx.path ~= nil then
    local python_root = ctx.python_root or ctx.project_root
    local relative_file = relpath(python_root, ctx.path)
    local ruff = resolve_binary(python_root, { "ruff" })
    local pytest = resolve_binary(python_root, { "pytest" })

    if ruff then
      add_shell_action(actions, "ruff check", { ruff, "check", relative_file }, python_root or ctx.dir)
    end
    if pytest then
      add_shell_action(actions, "pytest", { pytest, relative_file }, python_root or ctx.dir)
    end
  end

  if ctx.filetype == "go" and ctx.path ~= nil then
    local cwd = ctx.dir
    local golangci = resolve_binary(ctx.go_root or ctx.project_root, { "golangci-lint" })
    add_shell_action(actions, "go test .", { "go", "test", "." }, cwd)
    if golangci then
      add_shell_action(actions, "golangci-lint run .", { golangci, "run", "." }, cwd)
    end
  end

  if (ctx.filetype == "terraform" or ctx.filetype == "terraform-vars") and ctx.path ~= nil then
    local terraform = resolve_binary(ctx.project_root, { "terraform" })
    if terraform then
      add_shell_action(actions, "terraform validate", { terraform, "validate" }, ctx.dir)
    end
  end

  if ctx.filetype == "toml" and ctx.path ~= nil then
    local taplo = resolve_binary(ctx.project_root, { "taplo" })
    if taplo then
      add_shell_action(actions, "taplo lint", { taplo, "lint", ctx.path }, ctx.project_root or ctx.dir)
    end
  end

  return actions
end

function M.pick_current_file_action(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local actions = M.available_actions(bufnr)

  if vim.tbl_isempty(actions) then
    vim.notify("現在ファイル向けに解決できる action がありません", vim.log.levels.WARN)
    return
  end

  vim.ui.select(vim.tbl_map(function(action)
    return action.label
  end, actions), {
    prompt = "Current file action を選択",
  }, function(_, idx)
    local action = idx and actions[idx] or nil
    if action ~= nil then
      action.run()
    end
  end)
end

local function save_hooks_enabled()
  if vim.g.save_hooks_enabled == nil then
    vim.g.save_hooks_enabled = true
  end
  return vim.g.save_hooks_enabled
end

local function save_hook_should_run(bufnr)
  return save_hooks_enabled() and buf_is_file(bufnr) and not state.formatting_buffers[bufnr]
end

local function save_hook_pre(args)
  if not save_hook_should_run(args.buf) then
    return
  end

  local formatter = resolve_formatter(current_context(args.buf))
  if formatter ~= nil and formatter.kind == "lsp" then
    M.format_buffer({ buf = args.buf, silent = true, from_save = true })
  end
end

local function save_hook_post(args)
  if not save_hook_should_run(args.buf) then
    return
  end

  local formatter = resolve_formatter(current_context(args.buf))
  if formatter == nil or formatter.kind ~= "cli" then
    return
  end

  state.formatting_buffers[args.buf] = true
  M.format_buffer({ buf = args.buf, silent = true, from_save = true })
  state.formatting_buffers[args.buf] = nil
end

local function create_save_hook_commands()
  pcall(vim.api.nvim_del_user_command, "CurrentFileActions")
  pcall(vim.api.nvim_del_user_command, "FormatBuffer")
  pcall(vim.api.nvim_del_user_command, "SaveHooksEnable")
  pcall(vim.api.nvim_del_user_command, "SaveHooksDisable")
  pcall(vim.api.nvim_del_user_command, "SaveHooksToggle")

  vim.api.nvim_create_user_command("CurrentFileActions", function()
    M.pick_current_file_action()
  end, {})
  vim.api.nvim_create_user_command("FormatBuffer", function()
    M.format_buffer()
  end, {})
  vim.api.nvim_create_user_command("SaveHooksEnable", function()
    vim.g.save_hooks_enabled = true
    vim.notify("save hook を有効化しました", vim.log.levels.INFO)
  end, {})
  vim.api.nvim_create_user_command("SaveHooksDisable", function()
    vim.g.save_hooks_enabled = false
    vim.notify("save hook を無効化しました", vim.log.levels.INFO)
  end, {})
  vim.api.nvim_create_user_command("SaveHooksToggle", function()
    vim.g.save_hooks_enabled = not save_hooks_enabled()
    local status = save_hooks_enabled() and "有効" or "無効"
    vim.notify("save hook を " .. status .. " にしました", vim.log.levels.INFO)
  end, {})
end

function M.setup()
  if state.setup_done then
    return
  end

  save_hooks_enabled()
  create_save_hook_commands()

  local group = vim.api.nvim_create_augroup("CurrentFileSaveHooks", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = save_hook_pre,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = save_hook_post,
  })

  vim.keymap.set("n", "<leader>xa", "<cmd>CurrentFileActions<CR>", {
    noremap = true,
    silent = true,
    desc = "現在ファイルの action を実行",
  })
  vim.keymap.set("n", "<leader>xf", "<cmd>FormatBuffer<CR>", {
    noremap = true,
    silent = true,
    desc = "現在バッファを format",
  })
  vim.keymap.set("n", "<leader>xh", "<cmd>SaveHooksToggle<CR>", {
    noremap = true,
    silent = true,
    desc = "save hook を切り替え",
  })

  state.setup_done = true
end

return M
