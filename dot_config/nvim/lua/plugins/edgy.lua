local git_panel_state = {}
local git_panel_open_pending = false

local function current_tab_wins()
  return vim.api.nvim_tabpage_list_wins(0)
end

local function git_panel_find_window()
  for _, win in ipairs(current_tab_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "chezmoi_git_panel" then
      return win, buf
    end
  end
  return nil, nil
end

local function find_filesystem_window()
  for _, win in ipairs(current_tab_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" and vim.b[buf].neo_tree_source == "filesystem" then
      return win
    end
  end
  return nil
end

local function resize_left_sidebar()
  local files_win = find_filesystem_window()
  if files_win and vim.api.nvim_win_is_valid(files_win) then
    vim.api.nvim_win_call(files_win, function()
      pcall(vim.cmd, "vertical resize 35")
    end)
  end
end

local function current_repo(callback)
  local cwd = vim.fn.getcwd()
  vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = cwd }, function(result)
    vim.schedule(function()
      local repo = result.code == 0 and vim.trim(result.stdout or "") or cwd
      callback(repo)
    end)
  end)
end

local function parse_status(stdout)
  local entries = {}
  for line in (stdout or ""):gmatch("[^\r\n]+") do
    local status = line:sub(1, 2)
    local path = vim.trim(line:sub(4))
    path = path:match(".+ %-> (.+)") or path
    if path ~= "" then
      table.insert(entries, { status = status, path = path })
    end
  end
  return entries
end

local function parse_commits(stdout)
  local commits = {}
  for line in (stdout or ""):gmatch("[^\r\n]+") do
    local hash, subject = line:match("^(%S+)%s+(.+)$")
    if hash and subject then
      table.insert(commits, { hash = hash, subject = subject })
    end
  end
  return commits
end

local function git_panel_render(buf)
  local state = git_panel_state[buf]
  if not state or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {
    "Git",
    "Repo: " .. vim.fn.fnamemodify(state.repo, ":t"),
    "",
    "Status",
  }
  local items = {}

  local function push(line, item)
    table.insert(lines, line)
    items[#lines] = item
  end

  if #state.status == 0 then
    push("  clean", { type = "noop" })
  else
    for _, entry in ipairs(state.status) do
      push(string.format("  %s %s", entry.status, entry.path), { type = "file", path = entry.path })
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Log")
  if #state.commits == 0 then
    push("  コミット履歴なし", { type = "noop" })
  else
    for _, commit in ipairs(state.commits) do
      local marker = state.selected_commit == commit.hash and "-" or "+"
      push(string.format("  %s %s %s", marker, commit.hash, commit.subject), { type = "commit", commit = commit })
      if state.selected_commit == commit.hash then
        local files = state.commit_files[commit.hash] or {}
        if #files == 0 then
          push("    変更ファイルなし", { type = "noop" })
        else
          for _, path in ipairs(files) do
            push("    " .. path, { type = "file", path = path })
          end
        end
      end
    end
  end

  state.items = items
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function git_panel_refresh(buf)
  local state = git_panel_state[buf]
  if not state then return end

  vim.system({ "git", "-c", "core.quotePath=false", "status", "--short", "--untracked-files=all" },
    { text = true, cwd = state.repo },
    function(status_result)
      vim.system({ "git", "log", "--oneline", "--decorate", "-n", "30" },
        { text = true, cwd = state.repo },
        function(log_result)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then return end
            state.status = status_result.code == 0 and parse_status(status_result.stdout) or {}
            state.commits = log_result.code == 0 and parse_commits(log_result.stdout) or {}
            git_panel_render(buf)
          end)
        end)
    end)
end

local function git_panel_open_file(buf, path, open_cmd)
  local state = git_panel_state[buf]
  if not state then return end
  local fullpath = vim.fs.joinpath(state.repo, path)
  if vim.fn.filereadable(fullpath) ~= 1 then
    vim.notify("現在の状態で開けるファイルがありません: " .. path, vim.log.levels.WARN)
    return
  end

  local target_win
  for _, win in ipairs(current_tab_wins()) do
    local win_buf = vim.api.nvim_win_get_buf(win)
    local filetype = vim.bo[win_buf].filetype
    local buftype = vim.bo[win_buf].buftype
    local win_config = vim.api.nvim_win_get_config(win)
    if win_config.relative == "" and buftype == "" and filetype ~= "neo-tree" and filetype ~= "chezmoi_git_panel" then
      target_win = win
      break
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  elseif open_cmd ~= "tabedit" then
    vim.cmd("botright vertical new")
    open_cmd = "edit"
  end

  vim.cmd((open_cmd or "edit") .. " " .. vim.fn.fnameescape(fullpath))
end

local function git_panel_select(buf, open_cmd)
  local state = git_panel_state[buf]
  if not state then return end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local item = state.items[line]
  if not item or item.type == "noop" then
    return
  end

  if item.type == "file" then
    git_panel_open_file(buf, item.path, open_cmd)
    return
  end

  if item.type == "commit" then
    local hash = item.commit.hash
    if state.selected_commit == hash then
      state.selected_commit = nil
      git_panel_render(buf)
      return
    end

    state.selected_commit = hash
    if state.commit_files[hash] then
      git_panel_render(buf)
      return
    end

    vim.system({ "git", "-c", "core.quotePath=false", "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", hash },
      { text = true, cwd = state.repo },
      function(result)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then return end
          local files = {}
          if result.code == 0 then
            for path in (result.stdout or ""):gmatch("[^\r\n]+") do
              if path ~= "" then table.insert(files, path) end
            end
          end
          state.commit_files[hash] = files
          git_panel_render(buf)
        end)
      end)
  end
end

local function open_git_panel(repo)
  local previous_win = vim.api.nvim_get_current_win()
  local files_win = find_filesystem_window()
  if not files_win then
    require("neo-tree.command").execute({
      source = "filesystem",
      position = "left",
      action = "show",
    })
    files_win = find_filesystem_window()
  end

  if files_win and vim.api.nvim_win_is_valid(files_win) then
    vim.api.nvim_set_current_win(files_win)
    resize_left_sidebar()
    vim.cmd("belowright split")
  else
    vim.cmd("topleft vertical 35new")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "chezmoi_git_panel"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.wrap = false

  git_panel_state[buf] = {
    repo = repo,
    status = {},
    commits = {},
    commit_files = {},
    selected_commit = nil,
    items = {},
  }

  for _, lhs in ipairs({ "<CR>", "o", "l" }) do
    vim.keymap.set("n", lhs, function() git_panel_select(buf) end, { buffer = buf, silent = true, desc = "選択" })
  end
  vim.keymap.set("n", "<C-h>", function() git_panel_select(buf, "split") end, { buffer = buf, silent = true, desc = "横分割で開く" })
  vim.keymap.set("n", "<C-v>", function() git_panel_select(buf, "vsplit") end, { buffer = buf, silent = true, desc = "縦分割で開く" })
  vim.keymap.set("n", "<C-t>", function() git_panel_select(buf, "tabedit") end, { buffer = buf, silent = true, desc = "タブで開く" })
  vim.keymap.set("n", "r", function() git_panel_refresh(buf) end, { buffer = buf, silent = true, desc = "更新" })
  vim.keymap.set("n", "q", function()
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, silent = true, desc = "閉じる" })

  git_panel_refresh(buf)

  if vim.api.nvim_win_is_valid(previous_win) then
    vim.api.nvim_set_current_win(previous_win)
  end
end

local function toggle_git_panel()
  local git_win = git_panel_find_window()
  if git_win and vim.api.nvim_win_is_valid(git_win) then
    vim.api.nvim_win_close(git_win, true)
    resize_left_sidebar()
    return
  end

  if git_panel_open_pending then
    return
  end

  git_panel_open_pending = true
  current_repo(function(repo)
    git_panel_open_pending = false
    local existing_win = git_panel_find_window()
    if existing_win and vim.api.nvim_win_is_valid(existing_win) then
      return
    end
    open_git_panel(repo)
  end)
end

return {
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      vim.opt.laststatus = 3
      vim.opt.splitkeep = "screen"
    end,
    opts = {
      animate = {
        enabled = false,
      },
      options = {
        left = { size = 35 },
        bottom = { size = 12 },
      },
      left = {
        {
          title = "Files",
          ft = "neo-tree",
          filter = function(buf)
            return vim.b[buf].neo_tree_source == "filesystem"
          end,
          size = { height = 0.5 },
        },
        {
          title = "Git",
          ft = "chezmoi_git_panel",
          pinned = true,
          size = { height = 0.5 },
        },
        "neo-tree",
      },
      bottom = {
        {
          ft = "toggleterm",
          size = { height = 0.3 },
          filter = function(_, win)
            return vim.api.nvim_win_get_config(win).relative == ""
          end,
        },
        { ft = "qf", title = "QuickFix" },
      },
      keys = {
        ["q"] = function(win)
          win:close()
        end,
        ["Q"] = function(win)
          win.view.edgebar:close()
        end,
        ["<c-q>"] = function(win)
          win:hide()
        end,
        ["]w"] = function(win)
          win:next({ visible = true, focus = true })
        end,
        ["[w"] = function(win)
          win:prev({ visible = true, focus = true })
        end,
        ["<c-w>>"] = function(win)
          win:resize("width", 2)
        end,
        ["<c-w><lt>"] = function(win)
          win:resize("width", -2)
        end,
        ["<c-w>+"] = function(win)
          win:resize("height", 2)
        end,
        ["<c-w>-"] = function(win)
          win:resize("height", -2)
        end,
        ["<c-w>="] = function(win)
          win.view.edgebar:equalize()
        end,
      },
    },
    config = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "DiffviewFiles", "DiffviewFileHistory" },
        callback = function(args)
          vim.b[args.buf].edgy_disable = true
          local win = vim.fn.bufwinid(args.buf)
          if win ~= -1 then
            vim.w[win].edgy_disable = true
          end
        end,
      })

      require("edgy").setup(opts)

      vim.api.nvim_create_autocmd({ "TabEnter", "VimResized" }, {
        callback = function()
          vim.schedule(resize_left_sidebar)
        end,
      })
    end,
    keys = {
      {
        "<leader>ge",
        toggle_git_panel,
        desc = "Git パネルをトグル",
      },
      {
        "<leader>gE",
        function()
          require("edgy").select("left")
        end,
        desc = "左サイドバー内のウィンドウを選択",
      },
    },
  },
}
