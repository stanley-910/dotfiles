-- mini.ai — extend and create `a`/`i` textobjects.
--
-- Enhances builtin textobjects (a(, a), a", ...) and adds new ones, all under
-- the familiar `a`/`i` prefixes in Operator-pending and Visual modes. Highlights:
--   af / if   Treesitter function      (function/method/lambda node)
--   ac / ic   Treesitter function call (call expression / arguments)
--   aC / iC   Treesitter class         (class/interface/type-ish region)
--   ap / ip   Treesitter parameter     (function parameter or call argument)
--   ai / ii   Treesitter conditional   (if/switch/ternary-ish region)
--   al / il   Treesitter loop          (for/while/etc.)
--   aB / iB   Treesitter block         ({ ... } / block node)
--   ao / io   Treesitter control block (nearest conditional, loop, or block)
--   at / it   tag                      (<div>...</div>)
--   aq / iq   any quote   ab/ib any bracket   a?/i? prompt for custom delimiters
--   a<Space>  whitespace               plus a<punct>/a<digit> for non-letters
-- Full default list: :h MiniAi-builtin-textobjects
--
-- Defaults are kept as-is (see :h MiniAi.config) — sensible out of the box:
--   n_lines = 50, search_method = 'cover_or_next', goto edges on g[ / g].
--
-- No keymap conflicts: nothing in config/keymap.lua maps `a`/`i` in
-- operator/visual mode, nor g[ / g]. config/keymap.lua line ~374 explicitly
-- reserved this slot ("Rich textobjects: nvim-mini/mini.ai").
--
-- NOTE: mini.ai's default an/in next-textobject mappings conflict with
-- Neovim 0.12's builtin incremental-selection maps (:h v_an / :h v_in), so
-- keep an/in for native Treesitter/LSP node selection and disable mini.ai's
-- next/last variants below. See :h MiniAi.config.
--
-- Interaction with substitute.nvim: the `x` operator (gbprod/substitute) drives
-- `g@`/operatorfunc, so these textobjects apply automatically — `xif` substitutes
-- inside a function body, `xic` substitutes call arguments, etc. No extra mapping.
--
-- Treesitter-backed objects depend on reachable `textobjects.scm` queries. The
-- companion nvim-treesitter-textobjects plugin supplies those captures; verify
-- with: :lua =vim.treesitter.query.get_files(vim.bo.filetype, 'textobjects')
--
-- To remove: delete this file; the reserved-slot comment in keymap.lua still
-- documents the intent.
--
-- See: https://github.com/nvim-mini/mini.ai
return {
  "nvim-mini/mini.ai",
  version = "*", -- track tagged releases for stability
  event = "VeryLazy",
  opts = function()
    local ai = require("mini.ai")
    local ts = ai.gen_spec.treesitter
    local control = {
      "@conditional.outer",
      "@loop.outer",
      "@block.outer",
    }
    local control_inner = {
      "@conditional.inner",
      "@loop.inner",
      "@block.inner",
    }

    return {
      custom_textobjects = {
        -- Override mini.ai's pattern-based function-call `f` with the canonical
        -- Treesitter function object. Calls move to `c` so `vaf` selects the
        -- whole function declaration/expression instead of just `name()`.
        f = ts({ a = "@function.outer", i = "@function.inner" }),
        c = ts({ a = "@call.outer", i = "@call.inner" }),
        C = ts({ a = "@class.outer", i = "@class.inner" }),
        p = ts({ a = "@parameter.outer", i = "@parameter.inner" }),
        i = ts({ a = "@conditional.outer", i = "@conditional.inner" }),
        l = ts({ a = "@loop.outer", i = "@loop.inner" }),
        B = ts({ a = "@block.outer", i = "@block.inner" }),
        o = ts({ a = control, i = control_inner }),
      },
      mappings = {
        -- Preserve Neovim 0.12 defaults: v_an / v_in select parent/child nodes.
        around_next = "",
        inside_next = "",
        around_last = "",
        inside_last = "",
      },
    }
  end,
}
