return {
  "stevearc/conform.nvim",
  cmd = "ConformInfo",
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      sh = { "shfmt" },

      python = { "ruff_fix", "ruff_format" },
    },

    -- DISABLED: format-on-save caused a jarring "cursor flies from the top of
    -- the file back to position" on every save — conform rewrites the buffer via
    -- vim.lsp.util.apply_text_edits, and smear-cursor / Snacks scroll animate the
    -- resulting view/cursor movement. Formatting is on-demand only (conform
    -- keybind in lua/config/keymap.lua / :lua require("conform").format()).
    -- Uncomment to turn save-time formatting back on.
    -- format_on_save = {
    --   lsp_format = "fallback",
    --   timeout_ms = 500,
    -- },
  },
}
