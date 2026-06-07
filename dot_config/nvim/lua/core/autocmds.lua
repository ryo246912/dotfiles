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
      vim.cmd('Neotree filesystem show left')
      vim.cmd('wincmd l')
    end
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
