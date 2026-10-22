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
      local ok, neo_tree = pcall(require, 'neo-tree.command')
      if ok then
        neo_tree.execute({
          source = 'filesystem',
          position = 'left',
          action = 'show',
        })
        vim.cmd('wincmd l')
      end
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

-- mise の tera テンプレート（*.tera）は、.tera を外したファイル名から中身の filetype を判定し
-- "<中身>.tera" の複合 filetype にする（例: alacritty.toml.tera → toml.tera, git/config.tera → gitconfig.tera）。
-- 中身の syntax の上に after/syntax/tera.vim が tera タグのハイライトを重ねる。
-- vim-polyglot が did_load_filetypes を立てて Neovim 標準の filetype.lua（vim.filetype.add や
-- 組み込みの tera 検出を含む）を無効化するため、vim.filetype.add ではなく autocmd で設定している。
-- "toml" 単体にしないのは、テンプレートに taplo の LSP・format・lint を効かせないため。
local tera_group = vim.api.nvim_create_augroup('TeraTemplate', { clear = true })
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
  group = tera_group,
  pattern = '*.tera',
  callback = function(args)
    local path = vim.fn.fnamemodify(args.file, ':p'):gsub('%.tera$', '')
    -- templates/git/config のように「置き場所のディレクトリ名/ファイル名」で決まるものは
    -- フルパスでは判定できないため、~/.config 配下に置いた場合のパスでも判定する
    local inner = vim.filetype.match({ filename = path })
      or vim.filetype.match({
        filename = vim.fs.joinpath(vim.env.HOME, '.config', vim.fs.basename(vim.fs.dirname(path)), vim.fs.basename(path)),
      })
    vim.bo[args.buf].filetype = inner and (inner .. '.tera') or 'tera'
  end,
})
