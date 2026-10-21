-- WSLの場合はclip.exeでコピー
if vim.fn.has('unix') == 1 and vim.fn.system('uname -r'):find('microsoft') and vim.fn.system('uname'):find('Linux') then
  vim.api.nvim_create_augroup('Yank', { clear = true })
  -- +レジスタにyankされた場合のみ、クリップボードにコピー
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = 'Yank',
    callback = function()
      if vim.v.event.regname == '+' then
        vim.fn.system('clip.exe', vim.fn.getreg('"'))
      end
    end,
  })
end

-- nvim起動時にneo-treeを自動で開き、カーソルをエディタ側に移動
local neotree_open_group = vim.api.nvim_create_augroup('NeoTreeOpen', { clear = true })
vim.api.nvim_create_autocmd('VimEnter', {
  group = neotree_open_group,
  callback = function()
    local argv0 = vim.fn.argv(0)
    local is_no_arg = vim.fn.argc() == 0
    local is_dir_arg = vim.fn.argc() == 1 and vim.fn.isdirectory(argv0) == 1
    if is_no_arg or is_dir_arg then
      local ok, neotree = pcall(require, 'utils.neotree')
      if ok then
        neotree.open({ action = 'show' })
        vim.cmd('wincmd l')
      end
      return
    end

    -- `nvim file` のようにファイルを指定して起動した場合はツリーを出さず、ファイルだけを開く
    local function show_file_only()
      local target = vim.fn.fnamemodify(argv0, ':p')
      local tree_wins, file_win = {}, nil
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == 'neo-tree' then
          table.insert(tree_wins, win)
        elseif vim.api.nvim_buf_get_name(buf) == target then
          file_win = win
        end
      end
      if #tree_wins == 0 and file_win then
        return
      end

      if not file_win then
        -- ツリーしか無い場合は新しいウィンドウを作ってからファイルを開く
        -- （neo-tree のウィンドウ内で :edit すると neo-tree 側に横取りされるため）
        if #tree_wins == #vim.api.nvim_tabpage_list_wins(0) then
          vim.cmd('botright vnew')
        else
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'neo-tree' then
              vim.api.nvim_set_current_win(win)
              break
            end
          end
        end
        vim.cmd('edit ' .. vim.fn.fnameescape(argv0))
        file_win = vim.api.nvim_get_current_win()
      end

      for _, win in ipairs(tree_wins) do
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
      if vim.api.nvim_win_is_valid(file_win) then
        vim.api.nvim_set_current_win(file_win)
      end
    end
    -- neo-tree は非同期に描画されることがあるため、少し遅れて出てきたツリーも閉じる
    vim.schedule(show_file_only)
    vim.defer_fn(show_file_only, 300)
  end,
})

-- タブごとにtcdで独立したpwdを持つ
local tab_cwd_group = vim.api.nvim_create_augroup('TabLocalCwd', { clear = true })
vim.api.nvim_create_autocmd('TabNewEntered', {
  group = tab_cwd_group,
  callback = function()
    local dir = vim.fn.expand('%:p:h')
    if vim.fn.isdirectory(dir) == 1 then
      vim.cmd('tcd ' .. vim.fn.fnameescape(dir))
    end
  end,
})

-- :qa時にterminalバッファのjobを停止してから終了する
local quit_group = vim.api.nvim_create_augroup('QuitCleanup', { clear = true })
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = quit_group,
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
        local job_id = vim.b[buf].terminal_job_id
        if job_id then
          vim.fn.jobstop(job_id)
        end
      end
    end
  end,
})

-- terminalを開いたら即入力できるようにする（:terminal, split terminal, toggleterm共通）
local terminal_group = vim.api.nvim_create_augroup('TerminalInsert', { clear = true })
vim.api.nvim_create_autocmd('TermOpen', {
  group = terminal_group,
  pattern = '*',
  callback = function(args)
    if vim.bo[args.buf].buftype == 'terminal' then
      vim.cmd('startinsert')
    end
  end,
})
