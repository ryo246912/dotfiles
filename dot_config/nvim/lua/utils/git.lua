local M = {}

function M.is_git_root(dir)
  local git = dir .. "/.git"
  return vim.fn.isdirectory(git) == 1 or vim.fn.filereadable(git) == 1
end

-- cwd 配下のリポジトリ一覧を収集（cwd 自身 + 1〜2階層下）
function M.find_repos()
  local cwd = vim.fn.getcwd()
  local repos = {}
  if M.is_git_root(cwd) then
    table.insert(repos, cwd)
  end
  for _, p in ipairs(vim.fn.glob(cwd .. "/*/.git", false, true)) do
    local dir = vim.fn.fnamemodify(p, ":h")
    if M.is_git_root(dir) then table.insert(repos, dir) end
  end
  for _, p in ipairs(vim.fn.glob(cwd .. "/*/*/.git", false, true)) do
    local dir = vim.fn.fnamemodify(p, ":h")
    if M.is_git_root(dir) then table.insert(repos, dir) end
  end
  return repos
end

return M
