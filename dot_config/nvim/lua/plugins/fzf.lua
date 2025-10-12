return {
  {
    "junegunn/fzf",
    build = "./install --all",
  },
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    init = function()
      -- fzfコマンドのprefixを設定
      vim.g.fzf_command_prefix = 'Fzf'
    end,
    config = function()
      -- ctrl-{h,v}で垂直・水平分割で開く
      vim.g.fzf_action = {
        ['ctrl-y'] = 'split',
        ['ctrl-h'] = 'split',
        ['ctrl-v'] = 'vsplit',
        ['ctrl-t'] = 'vsplit'
      }

      -- Key mappings
      local keymap = vim.keymap.set

      -- bufferを表示
      keymap("n", "<leader>b", ":<C-u>:FzfBuffers<CR>", { noremap = true, silent = true })
      -- Commandを表示
      keymap("n", "<leader>C", ":<C-u>:FzfCommands<CR>", { noremap = true, silent = true })
      -- Filesを表示
      keymap("n", "<leader>f", ":<C-u>:FzfFiles<CR>", { noremap = true, silent = true })
      -- Helpを表示
      keymap("n", "<leader>H", ":<C-u>:FzfHelptags<CR>", { noremap = true, silent = true })
      -- ファイル履歴を表示
      keymap("n", "<leader>r", ":<C-u>:FzfHistory<CR>", { noremap = true, silent = true })
      -- コマンド履歴を表示
      keymap("n", "<leader>R", ":<C-u>:FzfHistory:<CR>", { noremap = true, silent = true })
      keymap("c", "<C-r>", ":<C-u>:FzfHistory:<CR>", { noremap = true })
      -- Windowを表示
      keymap("n", "<leader>w", ":<C-u>:FzfWindows<CR>", { noremap = true, silent = true })
    end,
  },
}
