-- theme file, highlight group overrides go here
return {
  -- {
  --   "rebelot/kanagawa.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   opts = {
  --     compile = false,
  --     theme = "wave",
  --     background = {
  --       dark = "wave",
  --       light = "lotus",
  --     },
  --     overrides = function(colors)
  --       return {
  --         DropBarMenuHoverEntry = { -- for ./dropbar.lua
  --           fg = colors.theme.ui.fg,
  --           bg = colors.palette.waveBlue1
  --         },
  --         -- SignColumn = {
  --         --   bg = "NONE"
  --         -- },
  --         --
  --         -- LineNr = { bg = "NONE" },
  --         -- GitSignsChange = { link = "SignColumn" }
  --       }
  --     end,
  --   },
  --   config = function(_, opts)
  --     require("kanagawa").setup(opts)
  --     vim.cmd.colorscheme("kanagawa")
  --   end,
  -- },
  {
    "tiagovla/tokyodark.nvim",
    opts = {
      -- custom options here
    },
    config = function(_, opts)
      require("tokyodark").setup(opts)   -- calling setup is optional
      vim.cmd [[colorscheme tokyodark]]
    end,
  }
}
