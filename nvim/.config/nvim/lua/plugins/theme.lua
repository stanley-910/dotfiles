-- theme file, highlight group overrides go here
return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      compile = false,
      theme = "wave",
      background = {
        dark = "wave",
        light = "lotus",
      },
      -- Flatten the gutter into the editor background: remap the wave bg_gutter
      -- slot (#2A2A37 -> Normal bg #1F1F28). This covers SignColumn, LineNr,
      -- CursorLineNr, FoldColumn AND the git/diff signs (GitSigns*, MiniDiffSign*)
      -- which all share bg_gutter. Cosmetic bg_p1 groups (ColorColumn, Folded,
      -- QuickFixLine, TabLineSel) keep their tint.
      colors = {
        theme = {
          wave = {
            ui = {
              bg_gutter = "#1f1f28",
            },
          },
        },
      },
      overrides = function(colors)
        return {
          DropBarMenuHoverEntry = { -- for ./dropbar.lua
            fg = colors.theme.ui.fg,
            bg = colors.palette.waveBlue1
          },
          -- SignColumn = {
          --   bg = "NONE"
          -- },
          --
          -- LineNr = { bg = "NONE" },
          -- GitSignsChange = { link = "SignColumn" }
        }
      end,
    },
    config = function(_, opts)
      require("kanagawa").setup(opts)
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}
