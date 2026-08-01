-- ghostty + tmux 環境で PDF をページ画像として nvim 内に表示する簡易ビューア。
-- poppler の pdftoppm でページ単位に PNG 化し、image.nvim の描画APIで
-- バッファを表示する各ウィンドウにレンダリングする。pdfinfo でページ数を取得しページ送りに対応する。

local M = {}

-- バッファ番号 -> ビューア状態
local states = {}

-- 一時PNG出力用ディレクトリ
local function tmp_dir()
  local dir = vim.fn.stdpath("cache") .. "/pdfview"
  vim.fn.mkdir(dir, "p")
  return dir
end

-- パス + 更新時刻 + サイズからキャッシュキーを生成する。
-- ファイル内容が更新されると mtime/size が変わるため、同名パスでも古いPNGを再利用しない。
local function cache_key(path)
  local st = vim.loop.fs_stat(path)
  local seed = path
  if st then
    seed = string.format("%s:%d:%d", path, st.mtime.sec, st.size)
  end
  return vim.fn.sha256(seed):sub(1, 16)
end

-- pdfinfo で総ページ数を取得。失敗時は 1 を返す。
local function get_page_count(path)
  local out = vim.fn.systemlist({ "pdfinfo", path })
  if vim.v.shell_error ~= 0 then
    return 1
  end
  for _, line in ipairs(out) do
    local n = line:match("^Pages:%s+(%d+)")
    if n then
      return tonumber(n)
    end
  end
  return 1
end

-- 指定ページを PNG 化し、そのパスを返す。失敗時は nil。
local function render_to_png(state)
  local prefix = string.format("%s/%s-%d", tmp_dir(), state.hash, state.page)
  local png = prefix .. ".png"
  if vim.fn.filereadable(png) == 0 then
    vim.fn.system({
      "pdftoppm",
      "-png",
      "-singlefile",
      "-r",
      tostring(state.dpi),
      "-f",
      tostring(state.page),
      "-l",
      tostring(state.page),
      state.path,
      prefix,
    })
    if vim.v.shell_error ~= 0 or vim.fn.filereadable(png) == 0 then
      return nil
    end
  end
  return png
end

-- 1つのウィンドウの画像をクリアし、winbar を元に戻す。
local function clear_window(state, win, entry)
  if entry.image then
    pcall(function()
      entry.image:clear()
    end)
  end
  if vim.api.nvim_win_is_valid(win) then
    pcall(function()
      vim.api.nvim_set_option_value("winbar", entry.saved_winbar or "", { win = win })
    end)
  end
  state.windows[win] = nil
end

-- 現在ページを、バッファを表示している全ウィンドウに描画する。
local function draw(state)
  local ok, image_api = pcall(require, "image")
  if not ok then
    vim.notify("image.nvim が読み込めませんでした", vim.log.levels.ERROR)
    return
  end

  local wins = vim.fn.win_findbuf(state.buf)
  if vim.tbl_isempty(wins) then
    return
  end

  local png = render_to_png(state)
  if not png then
    vim.notify("PDFのレンダリングに失敗しました (pdftoppm)", vim.log.levels.ERROR)
    return
  end

  -- 既にバッファを表示していないウィンドウの画像/winbar を後始末する
  for win, entry in pairs(state.windows) do
    if not vim.tbl_contains(wins, win) then
      clear_window(state, win, entry)
    end
  end

  for _, win in ipairs(wins) do
    -- ウィンドウ初出時のみ、上書き前の winbar を退避しておく
    local entry = state.windows[win]
    if not entry then
      entry = { saved_winbar = vim.wo[win].winbar }
      state.windows[win] = entry
    end

    -- 既存画像をクリアしてから再描画
    if entry.image then
      pcall(function()
        entry.image:clear()
      end)
      entry.image = nil
    end

    -- ページ全体が見えるようウィンドウ高さに合わせる（アスペクト比は image.nvim が維持）
    local img = image_api.from_file(png, {
      id = string.format("pdfview-%d-%d", state.buf, win),
      window = win,
      buffer = state.buf,
      with_virtual_padding = true,
      x = 0,
      y = 0,
      height = vim.api.nvim_win_get_height(win),
    })
    if img then
      img:render()
      entry.image = img
    end

    vim.api.nvim_set_option_value(
      "winbar",
      string.format(
        "PDF: %s  [%d/%d]  (J/K:ページ gg/G:先頭/末尾)",
        vim.fn.fnamemodify(state.path, ":t"),
        state.page,
        state.pages
      ),
      { win = win }
    )
  end
end

-- ページ移動（範囲外はクランプ）
local function goto_page(buf, page)
  local state = states[buf]
  if not state then
    return
  end
  page = math.max(1, math.min(state.pages, page))
  if page == state.page and not vim.tbl_isempty(state.windows) then
    return
  end
  state.page = page
  draw(state)
end

function M.next_page(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local state = states[buf]
  if state then
    goto_page(buf, state.page + 1)
  end
end

function M.prev_page(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local state = states[buf]
  if state then
    goto_page(buf, state.page - 1)
  end
end

-- PDF ファイルをビューアで開く。BufReadCmd から buf を受け取る想定。
function M.open(path, buf)
  path = vim.fn.fnamemodify(path, ":p")
  buf = buf or vim.api.nvim_get_current_buf()

  if vim.fn.executable("pdftoppm") == 0 then
    vim.notify("pdftoppm が見つかりません（brew:poppler をインストールしてください）", vim.log.levels.ERROR)
    return
  end

  -- 遅延ロードされている image.nvim を確実に読み込む
  pcall(function()
    require("lazy").load({ plugins = { "image.nvim" } })
  end)

  local state = {
    path = path,
    buf = buf,
    page = 1,
    pages = get_page_count(path),
    dpi = 150,
    hash = cache_key(path),
    windows = {}, -- win -> { image = <image>, saved_winbar = <string> }
  }
  states[buf] = state

  -- ビューア用バッファ（テキストは持たせない）
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdf"

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, desc = desc })
  end
  map("J", function()
    M.next_page(buf)
  end, "PDF: 次のページ")
  map("K", function()
    M.prev_page(buf)
  end, "PDF: 前のページ")
  map("<C-d>", function()
    M.next_page(buf)
  end, "PDF: 次のページ")
  map("<C-u>", function()
    M.prev_page(buf)
  end, "PDF: 前のページ")
  map("gg", function()
    goto_page(buf, 1)
  end, "PDF: 先頭ページ")
  map("G", function()
    goto_page(buf, state.pages)
  end, "PDF: 最終ページ")

  -- リサイズ時・新しいウィンドウ（split）表示時に再描画
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized", "BufWinEnter" }, {
    buffer = buf,
    callback = function()
      if states[buf] then
        draw(states[buf])
      end
    end,
  })

  -- バッファ破棄時に全ウィンドウの画像をクリアし winbar を復元する
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    buffer = buf,
    once = true,
    callback = function()
      local s = states[buf]
      if s then
        for win, entry in pairs(s.windows) do
          clear_window(s, win, entry)
        end
      end
      states[buf] = nil
    end,
  })

  -- ウィンドウ確定後に初回描画
  vim.schedule(function()
    if states[buf] then
      draw(states[buf])
    end
  end)
end

return M
