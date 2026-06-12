return {
  "gbprod/substitute.nvim",
  opts = {
    yank_substituted_text = false,
    preserve_cursor_position = false,
    highlight_substituted_text = {
      enabled = true,
      timer = 500,
    },
  },
  keys = {
    {
      "x",
      function()
        require("substitute").operator()
      end,
      mode = "n",
      desc = "Substitute operator",
    },
    {
      "xx",
      function()
        require("substitute").line()
      end,
      mode = "n",
      desc = "Substitute line",
    },
    {
      "X",
      function()
        require("substitute").eol()
      end,
      mode = "n",
      desc = "Substitute to end of line",
    },
    {
      "x",
      function()
        require("substitute").visual()
      end,
      mode = "x",
      desc = "Substitute selection",
    },
  },
}
