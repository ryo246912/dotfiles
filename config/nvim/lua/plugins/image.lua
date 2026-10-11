-- ghostty(Kitty graphics protocol) + tmux 環境で PDF を nvim 内に表示する。
-- ・.pdf を開くと utils.pdf の簡易ビューアでページ画像を描画（poppler + imagemagick）
-- ・markdown 内の画像表示は snacks.nvim (plugins/markdown.lua) が担当する
return {
  {
    "3rd/image.nvim",
    -- headless（`nvim --headless`, CI）では描画バックエンドを読み込まない
    cond = function()
      return #vim.api.nvim_list_uis() > 0
    end,
    -- utils.pdf が .pdf を開いたときに lazy.load する
    lazy = true,
    init = function()
      if #vim.api.nvim_list_uis() == 0 then
        return
      end
      -- .pdf はバイナリを読み込まず、そのままビューアへ引き渡す（拡張子の大文字/小文字を問わない）
      vim.api.nvim_create_autocmd("BufReadCmd", {
        group = vim.api.nvim_create_augroup("PdfView", { clear = true }),
        pattern = "*.[pP][dD][fF]",
        callback = function(args)
          require("utils.pdf").open(args.file, args.buf)
        end,
      })
    end,
    opts = {
      backend = "kitty", -- ghostty は Kitty graphics protocol 対応
      processor = "magick_cli", -- luarock 不要、imagemagick CLI を使用
      -- markdown は snacks.nvim で描画するため、二重描画しないよう無効化
      integrations = {
        markdown = { enabled = false },
      },
      -- tmux: 非アクティブpaneへの画像焼き付きを防ぐ
      tmux_show_only_in_active_window = true,
      window_overlap_clear_enabled = true,
    },
  },
}
