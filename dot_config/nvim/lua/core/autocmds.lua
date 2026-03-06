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
