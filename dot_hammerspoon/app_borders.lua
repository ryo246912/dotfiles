-- JankyBorders の枠の色をアプリ（プロセス）ごとに上書きする
--
-- ウィンドウの生成・フォーカス時に app_borders_rules.lua のルールを評価し、
-- `borders apply-to=<window-id> active_color=... inactive_color=...` でウィンドウ単位に色を設定する。
-- hs.window:id() は JankyBorders が管理する CGWindowID と同じ値。
-- JankyBorders の whitelist/blacklist はアプリ名でしか判別できないため、
-- 同じアプリを --user-data-dir 違いで複数起動した場合（Claude Desktop 等）もここで起動引数から判別する。
local M = {}

local BORDERS_CANDIDATES = { '/opt/homebrew/bin/borders', '/usr/local/bin/borders' }
-- ウィンドウ生成直後は JankyBorders 側の枠がまだ無く apply-to が無視されるため少し待つ
local CREATE_DELAY_SEC = 0.5

local args_cache = {} -- pid -> 起動引数
local pending = {} -- window id -> 生成時の遅延タイマー（GC 対策で参照を保持）

local function find_borders()
  for _, path in ipairs(BORDERS_CANDIDATES) do
    if hs.fs.attributes(path) then
      return path
    end
  end
end

local function process_args(pid)
  if not args_cache[pid] then
    -- -ww: 長い引数（--user-data-dir のパス等）を切り詰めない
    args_cache[pid] = hs.execute('ps -ww -o args= -p ' .. pid) or ''
  end
  return args_cache[pid]
end

local function match(rule, app)
  if rule.app and rule.app ~= app:name() and rule.app ~= app:bundleID() then
    return false
  end
  -- ps の起動コストがあるため app で絞り込んだ後に評価する
  if rule.args and not process_args(app:pid()):find(rule.args, 1, true) then
    return false
  end
  return true
end

local function inactive_of(color)
  local inactive = color:gsub('^0xff', '0x88')
  return inactive
end

local function paint(win)
  if not win or not win:id() then
    return
  end
  local app = win:application()
  if not app then
    return
  end
  for _, rule in ipairs(M.rules) do
    if match(rule, app) then
      -- フォーカスのたびに送り直すので、borders 再起動で上書きが消えても次のフォーカスで復帰する
      hs.task
        .new(M.borders, nil, {
          'apply-to=' .. win:id(),
          'active_color=' .. rule.color,
          'inactive_color=' .. (rule.inactive or inactive_of(rule.color)),
        })
        :start()
      return
    end
  end
end

function M.start(rules)
  M.rules = rules
  M.borders = find_borders()
  if not M.borders then
    hs.alert.show('app_borders: borders コマンドが見つかりません')
    return
  end

  M.filter = hs.window.filter.new()
  M.filter:subscribe(hs.window.filter.windowCreated, function(win)
    local id = win:id()
    if not id then
      return
    end
    pending[id] = hs.timer.doAfter(CREATE_DELAY_SEC, function()
      pending[id] = nil
      paint(win)
    end)
  end)
  M.filter:subscribe(hs.window.filter.windowFocused, paint)

  -- 終了したプロセスの起動引数キャッシュを捨てる（pid の再利用で誤判定しないように）
  M.app_watcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.terminated and app then
      local ok, pid = pcall(function()
        return app:pid()
      end)
      if ok and pid then
        args_cache[pid] = nil
      end
    end
  end)
  M.app_watcher:start()

  for _, win in ipairs(M.filter:getWindows()) do
    paint(win)
  end
end

return M
