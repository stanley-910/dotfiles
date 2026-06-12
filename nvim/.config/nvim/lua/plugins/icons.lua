return {
  {
    "nvim-mini/mini.icons",
    opts = {},
    config = function(_, opts)
      local icons = require("mini.icons")

      icons.setup(opts)
      icons.mock_nvim_web_devicons()
    end,
  },
}
