---@type vim.lsp.Config
return {
  cmd = { "ruff", "server" },
  on_attach = function(client)
    client.server_capabilities.documentFormattingProvider = false
  end
}
