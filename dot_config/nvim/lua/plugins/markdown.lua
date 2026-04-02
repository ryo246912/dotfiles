local function current_terminal()
  -- tmux can mask TERM_PROGRAM, so rely on emulator-specific env vars instead.
  if vim.env.WEZTERM_PANE or vim.env.WEZTERM_UNIX_SOCKET or vim.env.WEZTERM_EXECUTABLE then
    return "wezterm"
  end
  if vim.env.GHOSTTY_RESOURCES_DIR or vim.env.GHOSTTY_BIN_DIR then
    return "ghostty"
  end
  return nil
end

local function inline_image_enabled()
  return current_terminal() ~= "wezterm"
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      render_modes = true,
      heading = {
        width = "block",
        left_pad = 0,
        right_pad = 4,
        icons = {},
      },
      code = {
        width = "block",
      },
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      image = {
        enabled = true,
        doc = {
          inline = inline_image_enabled(),
          float = true,
        },
      },
    },
  },
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    cmd = "PasteImage",
    opts = {
      default = {
        dir_path = "assets",
        use_absolute_path = false,
        relative_to_current_file = true,
      },
    },
    keys = {
      { "<leader>ip", "<cmd>PasteImage<cr>", desc = "クリップボード画像を貼り付け" },
    },
  },
}
