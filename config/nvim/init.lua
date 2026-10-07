-- Disable netrw early to avoid neo-tree startup race
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Load core settings
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.abbreviations")
require("core.terraform_docs").setup()

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- setup lazy.nvim
-- AI エージェント環境（devcontainer / Docker Sandboxes）では ~/.config/nvim を read-only で
-- マウントするため、lazy.nvim が書き込む lockfile を state dir へ逃がす。
-- ホストでは従来どおり設定ディレクトリの lazy-lock.json を使う（AI_AGENT 未設定）。
local lockfile = nil
if vim.env.AI_AGENT then
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json"
end

require("lazy").setup({
  lockfile = lockfile,
  spec = {
    { import = "plugins" },
  },
  -- configure lazy.nvim options
  install = {
    colorscheme = { "tokyonight", "habamax" },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
})
