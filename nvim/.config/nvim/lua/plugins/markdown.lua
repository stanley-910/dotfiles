return {
  "MeanderingProgrammer/render-markdown.nvim",
  enabled = true,
  ft = "markdown",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    heading = {
      enabled = false,
    },
    code = {
      -- Keep rendered code blocks/language labels, but do not place language
      -- icons in the sign column for Snacks.statuscolumn to pick up.
      sign = false,
    },
  },
}
