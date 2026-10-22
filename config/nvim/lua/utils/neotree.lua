-- neo-tree を開くためのヘルパー。
-- nvim を長時間開きっぱなしにしていると、neo-tree 内部の状態（ウィンドウ/バッファの紐付けや
-- 読み込み中フラグ）が壊れて :Neotree を実行してもツリーが表示されなくなることがある。
-- そのため、開いた直後にツリーのウィンドウが出ていなければ状態をリセットして開き直す。

local M = {}

---現在のタブにある filesystem ソースの neo-tree ウィンドウを返す
---@return integer|nil
function M.find_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" and vim.b[buf].neo_tree_source == "filesystem" then
      return win
    end
  end
  return nil
end

---現在のタブの filesystem ソースの状態を破棄する（このタブの filesystem ツリーも閉じる）
---他のタブや git_status / buffers ソースの状態には触れない
---@return boolean ok
---@return string? err
function M.reset()
  return pcall(function()
    require("neo-tree.sources.manager").dispose("filesystem", vim.api.nvim_get_current_tabpage())
  end)
end

---@param args table
---@return boolean ok
---@return string? err
local function execute(args)
  return pcall(function()
    require("neo-tree.command").execute(args)
  end)
end

---ツリーを開く。表示されなければ状態をリセットしてもう一度開く。
---@param args table|nil neo-tree.command.execute に渡す引数
function M.open(args)
  args = vim.tbl_extend("force", { source = "filesystem", position = "left", action = "focus" }, args or {})
  local tab = vim.api.nvim_get_current_tabpage()
  -- 描画が少し遅れることがあるため、短時間待ってから判定する
  local function wait_window()
    return vim.wait(300, function()
      return M.find_window() ~= nil
    end, 20)
  end

  execute(args)
  if wait_window() then
    return
  end
  -- 待っている間に別のタブへ移っていたら、そのタブの状態を壊さないよう何もしない
  if vim.api.nvim_get_current_tabpage() ~= tab then
    return
  end

  local reset_ok, reset_err = M.reset()
  if not reset_ok then
    vim.notify("neo-tree の状態をリセットできませんでした: " .. tostring(reset_err), vim.log.levels.ERROR)
    return
  end
  local ok, err = execute(args)
  if not ok or not wait_window() then
    vim.notify("ファイルツリーを開けませんでした: " .. tostring(err or "ウィンドウが作成されませんでした"), vim.log.levels.ERROR)
  end
end

---ツリーが出ていれば閉じ、出ていなければ開く
function M.toggle()
  local win = M.find_window()
  if win and vim.api.nvim_win_is_valid(win) then
    execute({ source = "filesystem", action = "close" })
    return
  end
  M.open()
end

return M
