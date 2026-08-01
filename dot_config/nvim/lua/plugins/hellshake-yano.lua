-- hellshake-yano.vim: 連続したモーション操作でヒントを表示し高速にジャンプする
-- https://github.com/nekowasabi/hellshake-yano.vim
-- 依存: denops.vim + Deno ランタイム(mise で管理)
--
-- コマンド:
--   :HellshakeEnable  / :HellshakeDisable / :HellshakeToggle
--   :HellshakeShow    / :HellshakeHide
return {
  {
    "vim-denops/denops.vim",
    lazy = false,
  },
  {
    "nekowasabi/hellshake-yano.vim",
    dependencies = { "vim-denops/denops.vim" },
    event = "VeryLazy",
    -- vim.g は denops プラグイン読み込み前に設定する必要があるため init で設定する
    init = function()
      vim.g.hellshake_yano = {
        useJapanese = true,
        useHintGroups = true,
        motionCount = 3,
        defaultMinWordLength = 2,
      }
    end,
  },
}
