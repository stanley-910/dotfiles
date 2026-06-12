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
