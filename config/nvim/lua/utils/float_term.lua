-- フローティングターミナル（lazygit, hunk など）をプロセスを落とさずに表示/非表示する
local M = {}

-- group ごとに 1 セッション保持: { buf, win, job, exited }
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

local function is_valid(s)
  return s and vim.api.nvim_buf_is_valid(s.buf)
end

local function show(s)
  s.win = vim.api.nvim_open_win(s.buf, true, win_config())
  if not s.exited then
    vim.cmd("startinsert")
  end
end

local function hide(s)
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_hide(s.win)
  end
  s.win = nil
end

local function dispose(group, s)
  if sessions[group] == s then
    sessions[group] = nil
  end
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_close(s.win, true)
  end
  if vim.api.nvim_buf_is_valid(s.buf) then
    vim.api.nvim_buf_delete(s.buf, { force = true })
  end
end

-- 既存セッションがあれば表示/非表示を切り替えて true を返す。なければ false
function M.toggle(group)
  local s = sessions[group]
  if not is_valid(s) then
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
-- opts.cwd: 作業ディレクトリ
-- opts.close_on_exit: false ならコマンド終了後も出力を残す（q で閉じる）。既定 true
function M.open(group, cmd, opts)
  opts = opts or {}
  local old = sessions[group]
  if is_valid(old) then
    dispose(group, old)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  local s = { buf = buf }
  sessions[group] = s
  s.win = vim.api.nvim_open_win(buf, true, win_config())

  local ok, job = pcall(vim.fn.termopen, cmd, {
    cwd = opts.cwd,
    on_exit = function()
      vim.schedule(function()
        if opts.close_on_exit == false then
          s.exited = true
          if vim.api.nvim_buf_is_valid(buf) then
            vim.keymap.set({ "n", "t" }, "q", function() dispose(group, s) end,
              { buffer = buf, nowait = true, desc = "ポップアップを閉じる" })
          end
          return
        end
        dispose(group, s)
      end)
    end,
  })
  -- 起動に失敗したら空のセッションを残さない（残すと toggle が再起動を妨げる）
  if not ok or job <= 0 then
    dispose(group, s)
    vim.notify("ターミナルを起動できません: " .. tostring(ok and vim.inspect(cmd) or job), vim.log.levels.ERROR)
    return
  end
  s.job = job
  vim.cmd("startinsert")
end

return M
