return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  -- Group names map a key prefix to a label shown in the which-key popup.
  -- See :help which-key.nvim-which-key-mappings (the `spec` / group field).
  opts = {
    spec = {
      { "<leader>h", group = "git hunks" },
      { "<leader>c", group = "code / LSP" },
      { "<leader>D", group = "debug" },
      { "<leader>x", group = "diagnostics (trouble)" },
      -- Bracket-motion prefixes are not under a leader, but can still be labeled:
      { "]", group = "next" },
      { "[", group = "prev" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
