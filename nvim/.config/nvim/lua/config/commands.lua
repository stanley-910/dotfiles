vim.api.nvim_create_user_command("Dashboard", function()
  require("config.dashboard").open()
end, { desc = "Open Dashboard" })

-- Open the upstream page for the plugin defined in the current lua/plugins file.
-- Scans the buffer for the first "owner/repo" short spec (the form lazy.nvim
-- uses, e.g. "sphamba/smear-cursor.nvim"), then concatenates it onto a base URL
-- and hands the result to the OS via vim.ui.open(). :help vim.ui.open()
local function plugin_repo()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    -- long-bracket string so the quote chars in the pattern need no escaping
    local repo = line:match([=[["']([%w._-]+/[%w._-]+)["']]=])
    if repo then
      return repo
    end
  end
  return nil
end

local function open_plugin_url(base)
  local repo = plugin_repo()
  if not repo then
    vim.notify("No owner/repo plugin spec found in this buffer", vim.log.levels.WARN)
    return
  end
  vim.ui.open(base .. repo)
end

vim.api.nvim_create_user_command("PluginGithub", function()
  open_plugin_url("https://github.com/")
end, { desc = "Open this plugin's GitHub repo" })

vim.api.nvim_create_user_command("PluginDeepwiki", function()
  open_plugin_url("https://deepwiki.com/")
end, { desc = "Open this plugin's DeepWiki page" })
