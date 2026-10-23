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

    -- `nvim file` のようにファイルを指定して起動したのにツリーだけが表示されてしまう場合がある
    -- （手元の環境で報告されたが、原因の経路は未特定）。その場合はツリーを閉じてファイルだけを開く。
    -- ツリーが無ければ何もしないので、`-c bnext` などで選んだバッファや stdin（`nvim -`）には触れない。
    if argv0 == '' or argv0 == '-' then
      return
    end
    -- 遅延実行の間に cwd が変わっても同じファイルを指すよう、絶対パスは先に一度だけ求める
    local target = vim.fn.fnamemodify(argv0, ':p')

    ---@param allow_edit_beside_tree boolean ツリー以外のウィンドウがあるときにも起動ファイルを開き直してよいか
    local function show_file_only(allow_edit_beside_tree)
      local tree_wins, file_win = {}, nil
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == 'neo-tree' then
          table.insert(tree_wins, win)
        elseif vim.api.nvim_buf_get_name(buf) == target then
          file_win = win
        end
      end
      if #tree_wins == 0 then
        return
      end

      if not file_win then
        local tree_only = #tree_wins == #vim.api.nvim_tabpage_list_wins(0)
        -- 遅延実行では、ユーザーが別のファイルに切り替えたウィンドウを上書きしないよう、
        -- ツリーしか無いときだけファイルを開き直す
        if not tree_only and not allow_edit_beside_tree then
          return
        end
        -- ツリーしか無い場合は新しいウィンドウを作ってからファイルを開く
        -- （neo-tree のウィンドウ内で :edit すると neo-tree 側に横取りされるため）
        if tree_only then
          vim.cmd('botright vnew')
        else
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'neo-tree' then
              vim.api.nvim_set_current_win(win)
              break
            end
          end
        end
        vim.cmd('edit ' .. vim.fn.fnameescape(target))
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

    vim.schedule(function()
      show_file_only(true)
    end)
    -- neo-tree は非同期に描画されることがあるため、少し遅れて出てきたツリーも閉じる。
    -- ただし、その間にユーザーが別のバッファやタブへ移っていたら何もしない。
    local start_tab = vim.api.nvim_get_current_tabpage()
    vim.defer_fn(function()
      local cur_buf = vim.api.nvim_get_current_buf()
      local on_startup_view = vim.api.nvim_get_current_tabpage() == start_tab
        and (vim.api.nvim_buf_get_name(cur_buf) == target or vim.bo[cur_buf].filetype == 'neo-tree')
      if on_startup_view then
        show_file_only(false)
      end
    end, 300)
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
-- vim-polyglot は読み込み時に Neovim 標準の filetypedetect の autocmd を消し（au! filetypedetect）、
-- did_load_filetypes を立てて再読み込みも止める。そのため vim.filetype.add や組み込みの tera 検出は
-- 効かず（v0.12.5 + vim-polyglot で確認済み）、自前の autocmd で設定している。
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
