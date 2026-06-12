-- mini.ai — extend and create `a`/`i` textobjects.
--
-- Enhances builtin textobjects (a(, a), a", ...) and adds new ones, all under
-- the familiar `a`/`i` prefixes in Operator-pending and Visual modes. Highlights:
--   af / if   function call            (foo(bar) → name+parens / inside parens)
--   aa / ia   argument                 (one comma-separated arg, comma-aware)
--   at / it   tag                      (<div>...</div>)
--   aq / iq   any quote   ab/ib any bracket   a?/i? prompt for custom delimiters
--   a<Space>  whitespace               plus a<punct>/a<digit> for non-letters
-- Full list: :h MiniAi-builtin-textobjects
--
-- Defaults are kept as-is (see :h MiniAi.config) — sensible out of the box:
--   n_lines = 50, search_method = 'cover_or_next', goto edges on g[ / g].
--
-- No keymap conflicts: nothing in config/keymap.lua maps `a`/`i` in
-- operator/visual mode, nor g[ / g]. config/keymap.lua line ~374 explicitly
-- reserved this slot ("Rich textobjects: nvim-mini/mini.ai").
--
-- NOTE: an/in/al/il (next/last textobjects) deliberately override Neovim 0.12's
-- builtin incremental-selection maps. This config does not use those, so there
-- is nothing to lose. See :h MiniAi-default-an-in.
--
-- Interaction with substitute.nvim: the `x` operator (gbprod/substitute) drives
-- `g@`/operatorfunc, so these textobjects apply automatically — `xif` substitutes
-- inside a function call, `xaa` substitutes an argument, etc. No extra mapping.
--
-- To remove: delete this file; the reserved-slot comment in keymap.lua still
-- documents the intent.
--
-- See: https://github.com/nvim-mini/mini.ai
return {
  "nvim-mini/mini.ai",
  version = "*", -- track tagged releases for stability
  event = "VeryLazy",
  opts = {},
}
