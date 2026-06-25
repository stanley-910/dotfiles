-- lush.nvim — colorscheme dev tool with live preview (:Lushify).
-- Use it to tweak palette anchors in lua/theme/mine.lua, then derive/link the
-- rest of the colors from those roles.
return {
  "rktjmp/lush.nvim",
  -- Dev convenience: open the spec and live-preview in two steps.
  --   :e lua/theme/mine.lua
  --   :Lushify
  cmd = { "Lushify" },
}
