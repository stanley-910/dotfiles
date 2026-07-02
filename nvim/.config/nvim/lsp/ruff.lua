---@type vim.lsp.Config
return {
  cmd = { "ruff", "server" },
  on_attach = function(client)
    -- document why? is it because formatting done through conform?
    client.server_capabilities.documentFormattingProvider = false
  end
}
