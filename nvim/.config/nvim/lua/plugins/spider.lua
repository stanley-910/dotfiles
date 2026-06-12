-- nvim-spider — subword-aware w/e/b/ge motions.
--
-- The motions behave like vim's defaults but stop at the segments of
-- camelCase, SNAKE_CASE, and kebab-case identifiers, and skip punctuation
-- that is just syntax noise. This is the "subword motions" slot the
-- keymap.lua comment reserved (alongside flash.nvim for jumps).
--
-- Mapped in normal + operator + visual ({n,o,x}), so `w`, `dw`, and `vw`
-- all move by subword. The visual-mode `<M-w>`/`<M-b>`/`<M-e>` extend maps
-- in keymap.lua are untouched (those use the Alt modifier).
--
-- Defaults kept: skipInsignificantPunctuation = true (fewer, more useful
-- stops), consistentOperatorPending = false (cw keeps vim's change-to-word-end
-- quirk for muscle memory).
--
-- See: https://github.com/chrisgrieser/nvim-spider
return {
  "chrisgrieser/nvim-spider",
  opts = {},
  keys = {
    { "w",  mode = { "n", "o", "x" }, function() require("spider").motion("w") end,  desc = "Spider next subword start" },
    { "e",  mode = { "n", "o", "x" }, function() require("spider").motion("e") end,  desc = "Spider next subword end" },
    { "b",  mode = { "n", "o", "x" }, function() require("spider").motion("b") end,  desc = "Spider previous subword start" },
    { "ge", mode = { "n", "o", "x" }, function() require("spider").motion("ge") end, desc = "Spider previous subword end" },
  },
}
