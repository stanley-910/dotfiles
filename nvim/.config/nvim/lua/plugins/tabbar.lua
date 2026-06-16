return {
  "romgrk/barbar.nvim",
  event = "VeryLazy",
  dependencies = {
    "lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
    "nvim-mini/mini.icons",    -- OPTIONAL: for file icons
  },
  init = function()
    vim.g.barbar_auto_setup = false
  end,
  opts = {},
}
