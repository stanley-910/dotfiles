return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  -- Group names map a key prefix to a label shown in the which-key popup.
  -- See :help which-key.nvim-which-key-mappings (the `spec` / group field).
  opts = {
    delay = 100,

    -- Keep which-key out of Operator-pending mode; mini.ai owns textobject
    -- prompts directly. This avoids racing which-key's popup against mini.ai's
    -- getchar prompt after keys like `ci` / `ca`.
    triggers = {
      { "<auto>", mode = "nxsct" },
    },

    win = {
      -- Keep it anchored bottom-right instead of moving away from cursor.
      no_overlap = false,

      -- Negative row/col are relative to the far edge.
      -- This is the same positioning idea which-key's "helix" preset uses.
      row = -1,
      col = -1,

      border = "rounded",
      width = { min = 30, max = 60 },
      height = { min = 20, max = 60 },
    },

    spec = {
      { "<leader>h", group = "git hunks" },
      { "<leader>c", group = "code / LSP" },
      { "<leader>d", group = "debug" },
      { "<leader>x", group = "diagnostics (trouble)" },
      { "<leader>m", group = "marks / bookmarks" },
      { "<leader>q", group = "sessions" },
      -- Bracket-motion prefixes are not under a leader, but can still be labeled:
      { "]",         group = "next" },
      { "[",         group = "prev" },
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
    { "<leader>ql", "<cmd>SessionLoad<CR>", desc = "Load current session" },
    { "<leader>qp", "<cmd>SessionPrune<CR>", desc = "Prune stale sessions" },
    { "<leader>qP", "<cmd>SessionPrune!<CR>", desc = "Prune stale sessions (no prompt)" },
    { "<leader>qs", "<cmd>SessionSelect<CR>", desc = "Select session" },
    { "<leader>qS", "<cmd>SessionSave<CR>", desc = "Save and activate session" },
    { "<leader>qx", "<cmd>SessionStop<CR>", desc = "Stop session autosave" },
  },
}
