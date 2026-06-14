return {
  'stevearc/conform.nvim',
  opts = {
    formatters_by_ft = {
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      json = { 'prettier' },
      html = { 'prettier' },
      css = { 'prettier' },
      sh = { 'shfmt' },

      python = { 'ruff_fix', 'ruff_format' }
    },
    format_on_save = {
      lsp_format = "fallback",
      timeout_ms = 500
    }
  }
}
