local M = {}

local uv = vim.uv or vim.loop

local ROOT_MARKERS = {
  ".git",
  ".venv",
  "mise.toml",
  "package.json",
  "pyproject.toml",
  "go.mod",
  "taplo.toml",
  ".terraform",
}

local JS_LIKE_FILETYPES = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
}

local PRETTIER_FILETYPES = {
  graphql = true,
  graphqls = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  jsonc = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
  yaml = true,
}

local TERRAFORM_FILETYPES = {
  hcl = true,
  terraform = true,
  ["terraform-vars"] = true,
}

local function join_path(...)
  return vim.fs.joinpath(...)
end

local function stat(path)
  if not path or path == "" then
    return nil
  end
  return uv.fs_stat(path)
end

local function is_file(path)
  local info = stat(path)
  return info and info.type == "file" or false
end

local function is_directory(path)
  local info = stat(path)
  return info and info.type == "directory" or false
end

local function is_executable(path)
  return is_file(path) and vim.fn.executable(path) == 1
end

local function absolute_path(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

local function filename(path)
  return vim.fn.fnamemodify(path, ":t")
end

local function stem(path)
  return vim.fn.fnamemodify(path, ":t:r")
end

local function shell_join(argv)
  local escaped = vim.tbl_map(vim.fn.shellescape, argv)
  return table.concat(escaped, " ")
end

local function trim_message(text)
  if not text or text == "" then
    return ""
  end
  return vim.trim(text:gsub("%s+", " "))
end

local function buffer_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  if path == "" then
    return nil
  end
  return absolute_path(path)
end

local function relative_to(root, path)
  local root_path = absolute_path(root):gsub("/+$", "")
  local target_path = absolute_path(path)
  if target_path == root_path then
    return ""
  end
  local prefix = root_path .. "/"
  if target_path:sub(1, #prefix) == prefix then
    return target_path:sub(#prefix + 1)
  end
  return nil
end

local function find_project_root(path)
  local start_dir = dirname(path)
  local match = vim.fs.find(ROOT_MARKERS, { upward = true, path = start_dir })[1]
  if match then
    return dirname(match)
  end
  return start_dir
end

function M.project_root(bufnr)
  local path = buffer_path(bufnr or 0)
  if not path then
    return uv.cwd()
  end
  return find_project_root(path)
end

local function build_action(kind, label, argv, cwd)
  if not argv or #argv == 0 then
    return nil
  end
  return {
    kind = kind,
    label = label,
    argv = argv,
    cwd = cwd,
  }
end

local function push_action(actions, action)
  if action then
    table.insert(actions, action)
  end
end

local function detect_package_runner(root)
  if is_file(join_path(root, "pnpm-lock.yaml")) and vim.fn.executable("pnpm") == 1 then
    return { "pnpm", "exec" }
  end
  if is_file(join_path(root, "yarn.lock")) and vim.fn.executable("yarn") == 1 then
    return { "yarn", "exec" }
  end
  if (is_file(join_path(root, "bun.lock")) or is_file(join_path(root, "bun.lockb"))) and vim.fn.executable("bunx") == 1 then
    return { "bunx" }
  end
  if is_file(join_path(root, "package-lock.json")) and vim.fn.executable("npm") == 1 then
    return { "npm", "exec", "--" }
  end
  return nil
end

local function package_json_declares_tool(root, tool)
  local package_json = join_path(root, "package.json")
  if not is_file(package_json) then
    return false
  end

  local lines = vim.fn.readfile(package_json)
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(decoded) ~= "table" then
    return false
  end

  local dependency_keys = {
    "dependencies",
    "devDependencies",
    "optionalDependencies",
    "peerDependencies",
  }

  for _, key in ipairs(dependency_keys) do
    local deps = decoded[key]
    if type(deps) == "table" and deps[tool] ~= nil then
      return true
    end
  end

  return false
end

local function node_tool_argv(root, tool, args)
  local local_bin = join_path(root, "node_modules", ".bin", tool)
  if is_executable(local_bin) then
    return vim.list_extend({ local_bin }, args)
  end

  if vim.fn.executable(tool) == 1 then
    return vim.list_extend({ tool }, args)
  end

  local runner = detect_package_runner(root)
  if runner and package_json_declares_tool(root, tool) then
    local argv = vim.deepcopy(runner)
    table.insert(argv, tool)
    return vim.list_extend(argv, args)
  end

  return nil
end

local function python_tool_argv(root, tool, args)
  local candidates = {
    join_path(root, ".venv", "bin", tool),
    join_path(root, "venv", "bin", tool),
  }

  for _, candidate in ipairs(candidates) do
    if is_executable(candidate) then
      return vim.list_extend({ candidate }, args)
    end
  end

  if vim.fn.executable(tool) == 1 then
    return vim.list_extend({ tool }, args)
  end

  return nil
end

local function global_tool_argv(tool, args)
  if vim.fn.executable(tool) == 1 then
    return vim.list_extend({ tool }, args)
  end
  return nil
end

local function find_js_test_target(root, file_path)
  local current = filename(file_path)
  if current:match("%.test%.[^.]+$") or current:match("%.spec%.[^.]+$") then
    return file_path
  end

  local current_dir = dirname(file_path)
  local base = stem(file_path)
  local candidates = {}
  local extensions = { "js", "jsx", "ts", "tsx", "mjs", "cjs", "mts", "cts", "vue" }

  for _, suffix in ipairs({ ".test", ".spec" }) do
    for _, extension in ipairs(extensions) do
      table.insert(candidates, join_path(current_dir, base .. suffix .. "." .. extension))
      table.insert(candidates, join_path(current_dir, "__tests__", base .. suffix .. "." .. extension))
      table.insert(candidates, join_path(root, "tests", base .. suffix .. "." .. extension))
    end
  end

  for _, candidate in ipairs(candidates) do
    if is_file(candidate) then
      return candidate
    end
  end

  return nil
end

local function find_python_test_target(root, file_path)
  local current = filename(file_path)
  if current:match("^test_.+%.py$") or current:match(".+_test%.py$") then
    return file_path
  end

  local current_dir = dirname(file_path)
  local relative_dir = relative_to(root, current_dir)
  local tests_root = join_path(root, "tests")
  local base = stem(file_path)
  local candidates = {
    join_path(current_dir, "test_" .. base .. ".py"),
    join_path(current_dir, base .. "_test.py"),
    join_path(tests_root, "test_" .. base .. ".py"),
    join_path(tests_root, base .. "_test.py"),
  }

  if relative_dir and relative_dir ~= "" and relative_dir ~= "tests" and is_directory(tests_root) then
    table.insert(candidates, join_path(tests_root, relative_dir, "test_" .. base .. ".py"))
    table.insert(candidates, join_path(tests_root, relative_dir, base .. "_test.py"))
  end

  for _, candidate in ipairs(candidates) do
    if is_file(candidate) then
      return candidate
    end
  end

  return nil
end

function M.get_buffer_actions(bufnr)
  local target_buf = bufnr or 0
  local file_path = buffer_path(target_buf)
  if not file_path then
    return {}
  end

  local filetype = vim.bo[target_buf].filetype
  local root = M.project_root(target_buf)
  local actions = {}

  if PRETTIER_FILETYPES[filetype] then
    push_action(actions, build_action("format", "Format current file (Prettier)", node_tool_argv(root, "prettier", { "--write", file_path }), root))

    if JS_LIKE_FILETYPES[filetype] then
      push_action(actions, build_action("lint", "Lint current file (ESLint)", node_tool_argv(root, "eslint", { file_path }), root))

      local test_target = find_js_test_target(root, file_path)
      if test_target then
        push_action(actions, build_action("test", "Test related file (Vitest)", node_tool_argv(root, "vitest", { "run", test_target }), root))
        push_action(actions, build_action("test", "Test related file (Jest)", node_tool_argv(root, "jest", { "--runInBand", test_target }), root))
      end
    else
      push_action(actions, build_action("lint", "Check current file format (Prettier)", node_tool_argv(root, "prettier", { "--check", file_path }), root))
    end
  elseif filetype == "python" then
    push_action(actions, build_action("format", "Format current file (Ruff)", python_tool_argv(root, "ruff", { "format", file_path }), root))
    push_action(actions, build_action("lint", "Lint current file (Ruff)", python_tool_argv(root, "ruff", { "check", file_path }), root))

    local test_target = find_python_test_target(root, file_path)
    if test_target then
      push_action(actions, build_action("test", "Test related file (Pytest)", python_tool_argv(root, "pytest", { test_target }), root))
    end
  elseif filetype == "go" then
    local package_dir = dirname(file_path)
    local relative_dir = relative_to(root, package_dir)
    local package_arg = relative_dir and relative_dir ~= "" and ("./" .. relative_dir) or "."

    push_action(actions, build_action("format", "Format current file (gofmt)", global_tool_argv("gofmt", { "-w", file_path }), root))
    push_action(actions, build_action("lint", "Lint current package (golangci-lint)", global_tool_argv("golangci-lint", { "run", package_arg }), root))
    push_action(actions, build_action("test", "Test current package (go test)", global_tool_argv("go", { "test", package_arg }), root))
  elseif TERRAFORM_FILETYPES[filetype] then
    local module_dir = dirname(file_path)

    push_action(actions, build_action("format", "Format current file (terraform fmt)", global_tool_argv("terraform", { "fmt", file_path }), module_dir))
    push_action(actions, build_action("lint", "Validate current module (terraform validate)", global_tool_argv("terraform", { "validate" }), module_dir))
  elseif filetype == "toml" then
    push_action(actions, build_action("format", "Format current file (taplo)", global_tool_argv("taplo", { "format", file_path }), root))
    push_action(actions, build_action("lint", "Check current file format (taplo)", global_tool_argv("taplo", { "format", "--check", file_path }), root))
  end

  return actions
end

function M.get_primary_action(bufnr, kind)
  for _, action in ipairs(M.get_buffer_actions(bufnr)) do
    if action.kind == kind then
      return action
    end
  end
  return nil
end

function M.action_to_shell_command(action)
  local command = shell_join(action.argv)
  if action.cwd and action.cwd ~= "" then
    return "cd " .. vim.fn.shellescape(action.cwd) .. " && " .. command
  end
  return command
end

function M.run_action_sync(action, opts)
  local options = opts or {}
  local result = vim.system(action.argv, { cwd = action.cwd, text = true }):wait()
  if result.code == 0 then
    return true, result
  end

  if options.notify_on_error ~= false then
    local message = trim_message(result.stderr ~= "" and result.stderr or result.stdout)
    if message == "" then
      message = "exit code " .. result.code
    end
    vim.notify(action.label .. " に失敗しました: " .. message, vim.log.levels.ERROR)
  end

  return false, result
end

local function reload_buffer_from_disk(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent checktime")
    end)
  end)
end

function M.prepare_action_run(bufnr, action)
  local target_buf = bufnr or 0
  if vim.bo[target_buf].buftype ~= "" then
    return action
  end

  if not vim.bo[target_buf].modified then
    return action
  end

  if action.kind == "format" then
    vim.b[target_buf].skip_next_save_hook = true
  end

  local ok, err = pcall(vim.api.nvim_buf_call, target_buf, function()
    vim.cmd("silent update")
  end)
  if ok then
    return action
  end

  vim.notify("現在のバッファを保存できなかったため、コマンドを実行できません: " .. tostring(err), vim.log.levels.ERROR)
  return nil
end

function M.format_buffer(bufnr)
  local target_buf = bufnr or 0
  local action = M.get_primary_action(target_buf, "format")
  if not action then
    vim.notify("このファイルタイプに対応する format コマンドが見つかりません。", vim.log.levels.WARN)
    return false
  end

  local prepared = M.prepare_action_run(target_buf, action)
  if not prepared then
    return false
  end

  local ok = M.run_action_sync(prepared, { notify_on_error = true })
  if ok then
    reload_buffer_from_disk(target_buf)
    vim.notify(prepared.label .. " を実行しました。", vim.log.levels.INFO)
  end
  return ok
end

function M.run_save_hooks(bufnr)
  local target_buf = bufnr or 0
  if vim.g.save_hooks_enabled == false then
    return
  end

  if vim.b[target_buf].skip_next_save_hook then
    vim.b[target_buf].skip_next_save_hook = nil
    return
  end

  if vim.bo[target_buf].buftype ~= "" or not vim.bo[target_buf].modifiable then
    return
  end

  local action = M.get_primary_action(target_buf, "format")
  if not action then
    return
  end

  local ok = M.run_action_sync(action, { notify_on_error = true })
  if ok then
    reload_buffer_from_disk(target_buf)
  end
end

local function set_save_hooks_enabled(enabled)
  vim.g.save_hooks_enabled = enabled
  if enabled then
    vim.notify("save hook を有効化しました。", vim.log.levels.INFO)
  else
    vim.notify("save hook を無効化しました。", vim.log.levels.INFO)
  end
end

function M.setup()
  if M._did_setup then
    return
  end

  M._did_setup = true
  vim.g.save_hooks_enabled = vim.g.save_hooks_enabled ~= false

  pcall(vim.api.nvim_del_user_command, "SaveHooksEnable")
  pcall(vim.api.nvim_del_user_command, "SaveHooksDisable")
  pcall(vim.api.nvim_del_user_command, "SaveHooksToggle")
  pcall(vim.api.nvim_del_user_command, "FormatBuffer")

  vim.api.nvim_create_user_command("SaveHooksEnable", function()
    set_save_hooks_enabled(true)
  end, {})

  vim.api.nvim_create_user_command("SaveHooksDisable", function()
    set_save_hooks_enabled(false)
  end, {})

  vim.api.nvim_create_user_command("SaveHooksToggle", function()
    set_save_hooks_enabled(not vim.g.save_hooks_enabled)
  end, {})

  vim.api.nvim_create_user_command("FormatBuffer", function()
    M.format_buffer(0)
  end, {})

  local group = vim.api.nvim_create_augroup("CurrentFileSaveHooks", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*",
    callback = function(args)
      require("core.file_actions").run_save_hooks(args.buf)
    end,
  })
end

return M
