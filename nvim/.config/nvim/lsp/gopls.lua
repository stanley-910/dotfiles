---@type vim.lsp.Config
return {
  settings = {
    -- gopls installed via `go install ...` not through Mason, so we can set custom global paths
    gopls = {
      gofumpt = true,
      staticcheck = true,
      analyses = {
        unusedparams = true,
      }
    }
  }
}
