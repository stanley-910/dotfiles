-- lush.nvim — colorscheme dev tool with live preview (:Lushify)
-- Pairs with minty.lua: use :Huefy to pick palette anchors, :Shades to
-- explore variants, then derive/link the rest in lua/theme/mine.lua.
return {
  "rktjmp/lush.nvim",
  -- Dev convenience: open the spec and live-preview in two steps.
  --   :e lua/theme/mine.lua
  --   :Lushify
  cmd = { "Lushify" },
}
