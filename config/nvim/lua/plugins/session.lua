return {
  {
    "rmagatti/auto-session",
    lazy = false,
    dependencies = { "ibhagwan/fzf-lua" },
    config = function()
      local auto_session = require("auto-session")
      local auto_session_lib = require("auto-session.lib")
      local restored_treesitter_state = {}

      local function buffer_path(bufnr)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == "" or vim.bo[bufnr].buftype ~= "" then
          return nil
        end
        return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
      end

      local function collect_treesitter_state()
        local state = {}
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            local path = buffer_path(bufnr)
            if path then
              state[path] = vim.treesitter.highlighter.active[bufnr] ~= nil
            end
          end
        end
        return state
      end

      local function restore_buffer_treesitter(bufnr)
        if not vim.api.nvim_buf_is_loaded(bufnr) then
          return
        end

        local path = buffer_path(bufnr)
        local enabled = path and restored_treesitter_state[path]
        if enabled == nil then
          return
        end

        if enabled then
          pcall(vim.treesitter.start, bufnr)
        else
          pcall(vim.treesitter.stop, bufnr)
        end
      end

      auto_session.setup({
        auto_save = true,
        auto_restore = false,
        auto_restore_last_session = false,
        single_session_mode = true,
        session_lens = {
          picker = "fzf",
        },
        save_extra_data = function()
          return vim.json.encode({
            treesitter = collect_treesitter_state(),
          })
        end,
        restore_extra_data = function(_, extra_data)
          local ok, data = pcall(vim.json.decode, extra_data)
          restored_treesitter_state = (
            ok
            and type(data) == "table"
            and type(data.treesitter) == "table"
            and data.treesitter
          ) or {}
          vim.schedule(function()
            for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
              restore_buffer_treesitter(bufnr)
            end
          end)
        end,
      })

      local function latest_session()
        return auto_session_lib.get_latest_session(auto_session.get_root_dir())
      end

      local TIMESTAMP_PATTERN = "_%d%d%d%d%d%d%d%d_%d%d%d%d%d%d$"

      local session_group = vim.api.nvim_create_augroup("AutoSessionCustom", { clear = true })
      vim.api.nvim_create_autocmd("VimEnter", {
        group = session_group,
        nested = true,
        callback = function()
          local has_no_args = vim.fn.argc() == 0
          local has_dir_arg = vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1
          if not has_no_args and not has_dir_arg then
            return
          end

          vim.schedule(function()
            local latest = latest_session()
            if latest then
              local session_name = vim.fn.fnamemodify(latest, ":t:r")
                :gsub(TIMESTAMP_PATTERN, "")
              local choice = vim.fn.confirm(
                "セッションを復元しますか？\n[" .. session_name .. "]",
                "&Yes\n&No",
                1
              )
              if choice == 1 then
                local ok, err = pcall(auto_session.restore_session, latest, { show_message = false })
                if not ok then
                  vim.notify("セッションの復元に失敗しました: " .. tostring(err), vim.log.levels.ERROR)
                end
              end
            end
          end)
        end,
      })

      local treesitter_group = vim.api.nvim_create_augroup("SessionTreesitterRestore", { clear = true })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
        group = treesitter_group,
        callback = function(args)
          restore_buffer_treesitter(args.buf)
        end,
      })

      local function has_floating_window()
        for _, winid in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(winid).relative ~= "" then
            return true
          end
        end
        return false
      end

      local save_timer = vim.uv.new_timer()
      if save_timer then
        save_timer:start(5 * 60 * 1000, 5 * 60 * 1000, vim.schedule_wrap(function()
          if vim.v.this_session ~= "" and vim.fn.mode(1):sub(1, 1) == "n" and not has_floating_window() then
            local active_session = vim.v.this_session
            local session_name = vim.fn.fnamemodify(active_session, ":t:r"):gsub(TIMESTAMP_PATTERN, "")
            local snapshot_name = session_name .. "_" .. os.date("%Y%m%d_%H%M%S")
            local ok = pcall(auto_session.save_session, snapshot_name, {
              show_message = false,
              is_autosave = true,
            })
            if ok then
              vim.v.this_session = active_session
            end
          end
        end))

        vim.api.nvim_create_autocmd("VimLeavePre", {
          callback = function()
            if not save_timer:is_closing() then
              save_timer:stop()
              save_timer:close()
            end
          end,
        })
      end

      vim.api.nvim_create_user_command("SessionRestoreLatest", function()
        local latest = latest_session()
        if not latest then
          vim.notify("復元できるセッションがありません", vim.log.levels.WARN)
          return
        end
        auto_session.restore_session(latest)
      end, {})

      vim.cmd("cabbr <expr> ss getcmdtype() ==# ':' && getcmdline() ==# 'ss' ? 'AutoSession save' : 'ss'")
      vim.cmd("cabbr <expr> sr getcmdtype() ==# ':' && getcmdline() ==# 'sr' ? 'AutoSession search' : 'sr'")
      vim.cmd("cabbr <expr> sl getcmdtype() ==# ':' && getcmdline() ==# 'sl' ? 'SessionRestoreLatest' : 'sl'")
    end,
  },
}
