-- ghostty + tmux 環境で PDF をページ画像として nvim 内に表示する簡易ビューア。
-- poppler の pdftoppm でページ単位に PNG 化し、image.nvim の描画APIで
-- バッファを表示する各ウィンドウにレンダリングする。pdfinfo でページ数を取得しページ送りに対応する。
-- 外部コマンド(pdftoppm/pdfinfo)は vim.system で非同期実行し、UIをブロックしない。

local M = {}

-- バッファ番号 -> ビューア状態
local states = {}

-- 一時PNG出力用ディレクトリ
local function tmp_dir()
  local dir = vim.fn.stdpath("cache") .. "/pdfview"
  vim.fn.mkdir(dir, "p")
  return dir
end

-- パス + 更新時刻(秒+ナノ秒) + サイズからキャッシュキーを生成する。
-- ファイル内容が更新されると mtime/size が変わるため、同名パスでも古いPNGを再利用しない。
-- 同一サイズのファイルを1秒以内に差し替えるケースに備え、mtime のナノ秒も含める。
local function cache_key(path)
  local st = vim.loop.fs_stat(path)
  local seed = path
  if st then
    seed = string.format("%s:%d:%d:%d", path, st.mtime.sec, st.mtime.nsec, st.size)
  end
  return vim.fn.sha256(seed):sub(1, 16)
end

-- 指定ハッシュのキャッシュPNG（<hash>-<page>.png）をすべて削除する。
-- バッファ破棄時や、内容が変わって別ハッシュで再レンダリングする際に呼び、
-- キャッシュディレクトリが無制限に肥大化するのを防ぐ。
local function delete_cached_pngs(hash)
  if not hash then
    return
  end
  local pattern = string.format("%s/%s-*.png", tmp_dir(), hash)
  for _, f in ipairs(vim.fn.glob(pattern, true, true)) do
    pcall(os.remove, f)
  end
end

-- except_buf 以外の生存中バッファが同じキャッシュハッシュを使っているか。
-- 同一PDFを別バッファ（split等）で開いた場合にキャッシュPNGを共有するため、
-- 片方の破棄時に他方が表示中のPNGを消さないよう判定に使う。
local function hash_in_use(hash, except_buf)
  for b, st in pairs(states) do
    if b ~= except_buf and st.hash == hash then
      return true
    end
  end
  return false
end

-- 外部コマンドを非同期実行し、完了後に（メインループ上で）cb(code, stdout_lines) を呼ぶ。
-- 途中でキャンセルできるようプロセスハンドル（vim.system の戻り値）を返す。
-- vim.system が使えない古い環境では同期実行にフォールバックする（この場合ハンドルは nil）。
local function run_async(cmd, cb)
  if vim.system then
    return vim.system(cmd, { text = true }, function(res)
      local lines = {}
      if res.stdout and res.stdout ~= "" then
        lines = vim.split(res.stdout, "\n", { trimempty = true })
      end
      vim.schedule(function()
        cb(res.code, lines)
      end)
    end)
  else
    local out = vim.fn.systemlist(cmd)
    cb(vim.v.shell_error, out)
    return nil
  end
end

-- pdfinfo で総ページ数を非同期取得し cb(pages) を呼ぶ。取得できない場合は失敗を通知しつつ 1 を返す。
local function get_page_count_async(path, cb)
  if vim.fn.executable("pdfinfo") == 0 then
    vim.notify("pdfinfo が見つかりません（ページ数を判定できず1ページとして表示します）", vim.log.levels.WARN)
    cb(1)
    return
  end
  run_async({ "pdfinfo", path }, function(code, lines)
    if code ~= 0 then
      vim.notify("pdfinfo の実行に失敗しました（1ページとして表示します）", vim.log.levels.WARN)
      cb(1)
      return
    end
    for _, line in ipairs(lines) do
      local n = line:match("^Pages:%s+(%d+)")
      if n then
        cb(tonumber(n))
        return
      end
    end
    vim.notify("pdfinfo の出力からページ数を判定できませんでした（1ページとして表示します）", vim.log.levels.WARN)
    cb(1)
  end)
end

-- 現在ページを非同期に PNG 化し、完了後に cb(png|nil) を呼ぶ。既存キャッシュがあれば即時。
local function render_to_png_async(state, cb)
  local prefix = string.format("%s/%s-%d", tmp_dir(), state.hash, state.page)
  local png = prefix .. ".png"
  if vim.fn.filereadable(png) == 1 then
    cb(png)
    return nil
  end
  return run_async({
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
  }, function(code, _)
    if code == 0 and vim.fn.filereadable(png) == 1 then
      cb(png)
    else
      cb(nil)
    end
  end)
end

-- 1つのウィンドウの画像をクリアし、winbar を元の値へ戻す。
-- ただし winbar は「自分が設定した値のまま」の場合のみ復元し、別バッファが上書き済みなら触らない
-- （複数ウィンドウで片方だけ別バッファに切替わった等で、新バッファの winbar を消さないため）。
local function clear_window(state, win, entry)
  if entry.image then
    pcall(function()
      entry.image:clear()
    end)
  end
  if vim.api.nvim_win_is_valid(win) and vim.wo[win].winbar == entry.pdf_winbar then
    pcall(function()
      vim.api.nvim_set_option_value("winbar", entry.saved_winbar or "", { win = win })
    end)
  end
  state.windows[win] = nil
end

-- 追跡中のウィンドウのうち、既にこのPDFバッファを表示していない（閉じられた/別バッファに切替わった）
-- ものを後始末する。winbar の残留と、別バッファの winbar 上書きを防ぐ。
local function reconcile(state)
  for win, entry in pairs(state.windows) do
    if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == state.buf) then
      clear_window(state, win, entry)
    end
  end
end

-- 現在ページを、バッファを表示している全ウィンドウに描画する（レンダリングは非同期）。
local function draw(state)
  local ok, image_api = pcall(require, "image")
  if not ok then
    vim.notify("image.nvim が読み込めませんでした", vim.log.levels.ERROR)
    return
  end

  -- 表示しなくなったウィンドウを先に後始末する
  reconcile(state)

  if vim.tbl_isempty(vim.fn.win_findbuf(state.buf)) then
    return
  end

  -- 既にレンダリング中なら、pdftoppm を多重起動せず「後でもう一度描画する」印だけ付けて戻る。
  -- 高速ページ送り中に必要なのは常に最新ページの1枚だけなので、in-flight は1本に抑える。
  if state.rendering then
    state.dirty = true
    return
  end
  state.rendering = true

  -- 非同期完了までに状態が変わりうるため、要求時点のページを控えておく
  local target_page = state.page

  state.job = render_to_png_async(state, function(png)
    state.rendering = false
    state.job = nil

    -- バッファが閉じられた/別状態に差し替わった場合は破棄
    if states[state.buf] ~= state then
      return
    end

    -- 要求時点のページのままレンダリングできた場合のみ描画する（追い越されていたら後段で再描画）
    if png and state.page == target_page then
      for _, win in ipairs(vim.fn.win_findbuf(state.buf)) do
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

        -- winbar は %{...} を式として評価するため、ファイル名中の % をエスケープしてから埋め込む
        local name = (vim.fn.fnamemodify(state.path, ":t"):gsub("%%", "%%%%"))
        local winbar = string.format(
          "PDF: %s  [%d/%d]  (J/K:ページ gg/G:先頭/末尾)",
          name,
          state.page,
          state.pages
        )
        vim.api.nvim_set_option_value("winbar", winbar, { win = win })
        -- 後片付け時に「自分が設定した値のまま」か判定するため控えておく
        entry.pdf_winbar = winbar
      end
    elseif not png and state.page == target_page then
      vim.notify("PDFのレンダリングに失敗しました (pdftoppm)", vim.log.levels.ERROR)
    end

    -- レンダリング中に更なる要求があった/ページが進んでいた場合は、最新状態で一度だけ再描画する
    if state.dirty or state.page ~= target_page then
      state.dirty = false
      draw(state)
    end
  end)
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

  -- 同じバッファを開き直す場合、進行中のレンダリングを止め、内容が変わってハッシュが
  -- 変わっていれば旧キャッシュを掃除する（他バッファが同ハッシュを使用中なら残す）
  local hash = cache_key(path)
  local prev = states[buf]
  if prev then
    if prev.job then
      pcall(function()
        prev.job:kill(15)
      end)
    end
    for win, entry in pairs(prev.windows) do
      clear_window(prev, win, entry)
    end
    if prev.hash and prev.hash ~= hash and not hash_in_use(prev.hash, buf) then
      delete_cached_pngs(prev.hash)
    end
  end

  local state = {
    path = path,
    buf = buf,
    page = 1,
    pages = 1, -- 実際のページ数は pdfinfo から非同期で更新する
    dpi = 150,
    hash = hash,
    windows = {}, -- win -> { image = <image>, saved_winbar = <string>, pdf_winbar = <string> }
  }
  states[buf] = state

  -- ビューア用バッファ（テキストは持たせない）
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdf"
  -- 最後のウィンドウが閉じられた時点でバッファを破棄し、後片付け(BufWipeout)を確実に走らせる。
  -- （:q で split を閉じただけでは通常バッファは hidden で残り、状態やキャッシュPNGが残留するため）
  vim.bo[buf].bufhidden = "wipe"

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, desc = desc })
  end
  map("J", function()
    M.next_page(buf)
  end, "PDF: 次のページ")
  map("K", function()
    M.prev_page(buf)
  end, "PDF: 前のページ")
  -- ページ画像はウィンドウ高に合わせて全体表示され、スクロールする余地が無いため、
  -- <C-d>/<C-u> は本来のハーフページスクロールではなくページ送りの別名として割り当てる。
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

  -- 同一バッファを開き直すと autocmd が累積するため、バッファ専用の augroup にまとめ、
  -- 再オープン時に clear=true で前回分を破棄してから貼り直す。
  local group = vim.api.nvim_create_augroup("PdfView_buf_" .. buf, { clear = true })

  -- 新しいウィンドウ（split）にこのバッファが表示されたら即再描画する。
  -- リサイズはモジュール全体のグローバルハンドラ側でまとめて扱う（非フォーカスの split も確実に再描画するため）。
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    buffer = buf,
    callback = function()
      if states[buf] then
        draw(states[buf])
      end
    end,
  })

  -- PDFバッファがウィンドウから外れる直前に、その窓の画像をクリアし winbar を同期的に元へ戻す。
  -- schedule すると次バッファの winbar 設定後に走り、それを上書きしてしまうため同期実行する。
  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    buffer = buf,
    callback = function()
      local s = states[buf]
      if not s then
        return
      end
      local win = vim.api.nvim_get_current_win()
      local entry = s.windows[win]
      if entry then
        clear_window(s, win, entry)
      end
    end,
  })

  -- バッファ破棄時に全ウィンドウの画像をクリアし winbar を復元、キャッシュPNGも削除する
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      local s = states[buf]
      if s then
        for win, entry in pairs(s.windows) do
          clear_window(s, win, entry)
        end
        -- 別バッファ（同一PDF）が同じキャッシュを使用中なら、進行中のレンダリングは
        -- 完了させ（有効なキャッシュとして残る）、PNGも削除しない。
        if not hash_in_use(s.hash, buf) then
          if s.job then
            pcall(function()
              s.job:kill(15)
            end)
          end
          delete_cached_pngs(s.hash)
        end
      end
      states[buf] = nil
    end,
  })

  -- 総ページ数を非同期取得し、判明後に初回描画する（winbar の [n/N] を正しく表示するため）。
  get_page_count_async(path, function(n)
    if states[buf] ~= state then
      return
    end
    state.pages = n
    vim.schedule(function()
      if states[buf] == state then
        draw(state)
      end
    end)
  end)
end

-- リサイズはグローバルに1回だけ登録する。バッファローカルな WinResized/VimResized は
-- 非フォーカスの split に確実に発火しないため、全 states をまとめて（デバウンスして）再描画する。
local resize_timer
vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
  group = vim.api.nvim_create_augroup("PdfViewGlobalResize", { clear = true }),
  callback = function()
    if resize_timer then
      resize_timer:stop()
    end
    resize_timer = vim.defer_fn(function()
      resize_timer = nil
      for _, state in pairs(states) do
        draw(state)
      end
    end, 80)
  end,
})

return M
