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

---neo-tree の全ソースの状態を破棄する（開いているツリーも閉じる）
function M.reset()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if ok and manager._clear_state then
    pcall(manager._clear_state)
  end
end

local function execute(args)
  local ok, err = pcall(require("neo-tree.command").execute, args)
  return ok, err
end

---ツリーを開く。表示されなければ状態をリセットしてもう一度開く。
---@param args table|nil neo-tree.command.execute に渡す引数
function M.open(args)
  args = vim.tbl_extend("force", { source = "filesystem", position = "left", action = "focus" }, args or {})
  execute(args)
  if M.find_window() then
    return
  end

  M.reset()
  local ok, err = execute(args)
  if not ok or not M.find_window() then
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
