local M = {}

local function fallback_browse()
  pcall(require("lazy").load, { plugins = { "gx.nvim" } })
  local ok = pcall(vim.cmd, "Browse")
  if not ok then
    vim.notify("URLを開けませんでした", vim.log.levels.WARN)
  end
end

local function open_url(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end

  local opener = vim.fn.has("mac") == 1 and "open" or vim.fn.has("wsl") == 1 and "wslview" or "xdg-open"
  if vim.fn.executable(opener) ~= 1 then
    vim.notify("URLを開くコマンドが見つかりません: " .. opener, vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart({ opener, url }, { detach = true })
end

local function find_resource_type_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local _, resource_prefix_end = line:find('%f[%w_]resource%f[^%w_]%s*"')

  if not resource_prefix_end then
    return nil
  end

  local type_start = resource_prefix_end + 1
  local type_end = line:find('"', type_start, true)

  if not type_end then
    return nil
  end

  type_end = type_end - 1
  if cursor_col < type_start or cursor_col > type_end + 1 then
    return nil
  end

  return line:sub(type_start, type_end)
end

local function parse_required_providers(bufnr)
  local providers = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local in_required_providers = false
  local current_provider = nil
  local depth = 0

  for _, line in ipairs(lines) do
    local stripped = line:gsub("#.*$", ""):gsub("//.*$", "")

    if not in_required_providers and stripped:match("%f[%w_]required_providers%f[^%w_]%s*{") then
      in_required_providers = true
      depth = 1
    elseif in_required_providers then
      depth = depth + select(2, stripped:gsub("{", "")) - select(2, stripped:gsub("}", ""))

      local inline_name, inline_source = stripped:match('([%w_-]+)%s*=%s*{%s*source%s*=%s*"([^"]+)"')
      if inline_name and inline_source then
        providers[inline_name] = inline_source
      end

      local provider_name = stripped:match("^%s*([%w_-]+)%s*=%s*{")
      if provider_name then
        current_provider = provider_name
      end

      local source = stripped:match('source%s*=%s*"([^"]+)"')
      if current_provider and source then
        providers[current_provider] = source
      end

      if stripped:match("^%s*}") then
        current_provider = nil
      end

      if depth <= 0 then
        break
      end
    end
  end

  return providers
end

local function provider_and_resource(resource_type, providers)
  local prefix, resource_name = resource_type:match("^([^_]+)_(.+)$")
  if not prefix or not resource_name then
    return nil, nil
  end

  return providers[prefix] or ("hashicorp/" .. prefix), resource_name
end

local function terraform_docs_url(resource_type)
  local providers = parse_required_providers(0)
  local provider_source, resource_name = provider_and_resource(resource_type, providers)
  if not provider_source then
    return nil
  end

  return string.format(
    "https://registry.terraform.io/providers/%s/latest/docs/resources/%s",
    provider_source,
    resource_name
  )
end

local function gx()
  local resource_type = find_resource_type_at_cursor()
  if not resource_type then
    fallback_browse()
    return
  end

  local url = terraform_docs_url(resource_type)
  if not url then
    fallback_browse()
    return
  end

  open_url(url)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("TerraformDocsGx", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "terraform", "terraform-vars", "hcl" },
    callback = function(args)
      vim.keymap.set("n", "gx", gx, {
        buffer = args.buf,
        noremap = true,
        silent = true,
        desc = "Terraform resource docsを開く",
      })
    end,
  })
end

return M
