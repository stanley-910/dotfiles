-- TreeSJ: tree-sitter-aware split/join for arrays, objects, calls, blocks, etc.
-- Keep the setup intentionally small: no custom language presets until a real
-- missed case appears. See :h treesj-settings after install.
return {
  "Wansmer/treesj",
  cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  keys = {
    {
      "g/",
      function()
        require("treesj").toggle()
      end,
      desc = "Toggle split/join syntax node",
    },
    {
      "<leader>tj",
      function()
        require("treesj").join()
      end,
      desc = "Join syntax node",
    },
    {
      "<leader>ts",
      function()
        require("treesj").split()
      end,
      desc = "Split syntax node",
    },
  },
  opts = {
    -- TreeSJ's defaults are <space>m/<space>j/<space>s; keep mappings explicit
    -- so they don't silently occupy leader slots already used by this config.
    use_default_keymaps = false,

    -- Conservative defaults kept visible because these are the knobs worth
    -- adjusting after living with the plugin for a bit.
    check_syntax_error = true,
    max_join_length = 120,
    cursor_behavior = "hold",
    notify = true,
    dot_repeat = true,
  },
}
