-- フローティングターミナル（lazygit, hunk など）をプロセスを落とさずに表示/非表示する
local M = {}

-- group ごとに 1 セッション保持: { buf, win, job }
local sessions = {}

local function win_config()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }
end

local function is_alive(s)
  return s and vim.api.nvim_buf_is_valid(s.buf) and vim.fn.jobwait({ s.job }, 0)[1] == -1
end

local function show(s)
  s.win = vim.api.nvim_open_win(s.buf, true, win_config())
  vim.cmd("startinsert")
end

local function hide(s)
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_hide(s.win)
  end
  s.win = nil
end

-- 既存セッションがあれば表示/非表示を切り替えて true を返す。なければ false
function M.toggle(group)
  local s = sessions[group]
  if not is_alive(s) then
    sessions[group] = nil
    return false
  end
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    hide(s)
  else
    show(s)
  end
  return true
end

-- 新しいセッションを開く（同じ group の既存セッションは終了させる）
function M.open(group, cmd, cwd)
  local old = sessions[group]
  if is_alive(old) then
    hide(old)
    vim.fn.jobstop(old.job)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  local s = { buf = buf }
  sessions[group] = s
  s.win = vim.api.nvim_open_win(buf, true, win_config())

  s.job = vim.fn.termopen(cmd, {
    cwd = cwd,
    on_exit = function()
      vim.schedule(function()
        if sessions[group] == s then
          sessions[group] = nil
        end
        if s.win and vim.api.nvim_win_is_valid(s.win) then
          vim.api.nvim_win_close(s.win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end

return M
