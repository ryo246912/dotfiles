-- Markdown の表示と画像まわり
-- ・render-markdown.nvim: 見出し/コードブロックの装飾
-- ・snacks.nvim (image): markdown 内の画像表示（ghostty は inline、非対応端末は float）
-- ・img-clip.nvim: クリップボード画像を assets/ に保存してリンクを挿入
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
    keys = {
      { "<leader>ih", function() Snacks.image.hover() end, desc = "カーソル位置の画像をフロート表示" },
    },
    ---@type snacks.Config
    opts = {
      image = {
        enabled = true,
        -- .pdf は utils.pdf (image.nvim) のビューアで開くため、snacks の BufReadCmd 対象から外す
        formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "icns" },
        doc = {
          -- unicode placeholder 非対応の端末(wezterm 等)では snacks が自動で inline を無効化し float になる
          inline = true,
          float = true,
          max_width = 80,
          max_height = 40,
        },
      },
    },
  },
  {
    "HakonHarnes/img-clip.nvim",
    cmd = "PasteImage",
    keys = {
      { "<leader>ip", "<cmd>PasteImage<cr>", desc = "クリップボード画像を貼り付け" },
    },
    opts = {
      default = {
        -- snacks.image の img_dirs に含まれる assets/ に保存し、編集中ファイルからの相対パスで挿入する
        dir_path = "assets",
        use_absolute_path = false,
        relative_to_current_file = true,
        prompt_for_file_name = true,
      },
    },
  },
}
