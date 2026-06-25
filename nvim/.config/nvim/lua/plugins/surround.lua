return {
  "kylechui/nvim-surround",
  version = "^4.0.0", -- Use for stability; omit to use `main` branch for the latest features
  event = "VeryLazy",
  init = function()
    -- Flash owns visual/operator `S`; keep surround on an explicit visual `gS`
    -- binding instead. See :help g:nvim_surround_no_visual_mappings and
    -- :help nvim-surround.keymaps.
    vim.g.nvim_surround_no_visual_mappings = true
  end,
  config = function()
    require("nvim-surround").setup({})
    vim.keymap.set("x", "S", "<Plug>(nvim-surround-visual)", {
      desc = "Add surround to selection",
    })
  end,
}
