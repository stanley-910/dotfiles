return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      modes = {
        buffer_diagnostics = {
          mode = "diagnostics",
          filter = { buf = 0 },
        },
      },
    },
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble buffer_diagnostics close<cr><cmd>Trouble diagnostics toggle focus=true<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics close<cr><cmd>Trouble buffer_diagnostics toggle focus=true<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle focus=true<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle focus=true<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  },
}
