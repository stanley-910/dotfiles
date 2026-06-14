local modules = {
  "config.options",
  "config.keymap",
  "config.autocmds",
  "config.lsp",
}

local function reload_module(name)
  package.loaded[name] = nil
  local ok, err = pcall(require, name)
  if not ok then
    vim.notify(("Reload failed for %s:\n%s"):format(name, err), vim.log.levels.ERROR)
    return false
  end
  return true
end

vim.api.nvim_create_user_command("ReloadConfig", function()
  local ok = true
  for _, name in ipairs(modules) do
    ok = reload_module(name) and ok
  end

  if ok then
    vim.notify("Reloaded config modules", vim.log.levels.INFO)
  end
end, { desc = "Reload modular Neovim config without restarting" })

local function source_after_ftplugin(ft)
  if not ft or ft == "" then
    return false
  end

  -- Personal filetype overrides belong under after/ftplugin. Re-source those
  -- directly so already-open buffers pick up changes without :edit/reopen.
  vim.cmd(("silent! runtime! after/ftplugin/%s.lua after/ftplugin/%s.vim"):format(ft, ft))
  return true
end

vim.api.nvim_create_user_command("ReloadFtplugin", function(command)
  local ft = command.args ~= "" and command.args or vim.bo.filetype
  if ft == "" then
    vim.notify("Current buffer has no filetype", vim.log.levels.WARN)
    return
  end

  local count = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == ft then
      vim.api.nvim_buf_call(bufnr, function()
        source_after_ftplugin(ft)
      end)
      count = count + 1
    end
  end

  vim.notify(("Reloaded after/ftplugin/%s for %d buffer(s)"):format(ft, count), vim.log.levels.INFO)
end, {
  nargs = "?",
  complete = function()
    return vim.fn.getcompletion("", "filetype")
  end,
  desc = "Reload after/ftplugin for the current or given filetype",
})

-- :Restart — a true quit + relaunch, not an in-process reload. Re-requiring
-- modules cannot tear down old keymaps/commands/LSP clients/plugin state, so
-- native :restart (Neovim 0.11+) re-execs the process for a genuinely clean
-- slate. The session round-trip below restores open buffers/windows/cursor so
-- it feels like reopening where you left off.
-- :help :restart  :help :mksession  :help 'sessionoptions'
local restart_session = vim.fn.stdpath("state") .. "/restart-session.vim"

vim.api.nvim_create_user_command("Restart", function(command)
  -- Capture the current layout (mksession honors 'sessionoptions': buffers,
  -- windows, tabs, cursor, cwd by default). The file's mere existence on the
  -- next launch is the "we just restarted" signal -- no separate marker needed.
  vim.cmd("mksession! " .. vim.fn.fnameescape(restart_session))
  -- Forward the bang: :Restart! force-quits modified buffers like :restart!.
  vim.cmd(command.bang and "restart!" or "restart")
end, { bang = true, desc = "Save session and restart Neovim (clean reload)" })

-- On the relaunched process, restore the saved session once, then delete it so
-- a later normal launch starts fresh. Registered here (before config.lazy in
-- init.lua) so this VimEnter runs before Snacks' dashboard handler: the
-- restored buffers make the dashboard's empty-start check skip itself.
-- Guarded to argc()==0 so it never clobbers an explicit `nvim <file>`.
-- FRAGILE SEAM: relies on init.lua load order vs the dashboard. If the
-- dashboard ever flashes on restart, revisit this ordering.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("RestartRestore", { clear = true }),
  nested = true, -- let restored buffers fire FileType/BufRead (LSP, treesitter)
  callback = function()
    if vim.fn.argc() ~= 0 or vim.fn.filereadable(restart_session) == 0 then
      return
    end
    local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(restart_session))
    vim.fn.delete(restart_session)
    if not ok then
      vim.notify("Restart restore failed:\n" .. tostring(err), vim.log.levels.ERROR)
    end
  end,
})
