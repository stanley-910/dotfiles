-- flash.nvim — label-based jump motions.
--
-- `s` + any chars labels every match in the visible area (both directions, all
-- windows by default); press the label to jump. `S` jumps by Treesitter node.
-- This is the slot the keymap.lua comment reserved for "Sneak/subword motions."
--
-- char mode enhances f/F/t/T: multi-line, repeatable, with jump labels on the
-- matches so you can teleport directly to a far match. This replaced mini.jump,
-- which only cycled through matches one at a time.
--
-- See: https://github.com/folke/flash.nvim
return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    keys = {
      { "s",       mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S",       mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r",       mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
      { "R",       mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<C-S-f>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" }, -- default <c-s> overwrites blink.cmp mapping
    },
  },
}

-- TODO figure out why the search / reverse search modes don't work, something in ../config/keymap.lua is fucking with it
