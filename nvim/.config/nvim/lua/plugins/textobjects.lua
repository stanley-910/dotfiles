-- nvim-treesitter-textobjects — curated Treesitter captures + structural motions.
--
-- Role split:
--   * nvim-treesitter-textobjects supplies maintained `textobjects.scm` queries
--     like @function.outer, @call.inner, @conditional.outer, etc.
--   * mini.ai consumes those captures for a/i textobjects (see mini-ai.lua).
--   * This file wires only structural ]/[ motions through the plugin's move API.
--
-- Conflict audit against current config:
--   * keep ]d/[d for diagnostics in config/lsp.lua
--   * keep ]h/[h for gitsigns hunks
--   * keep ];/[; for dropbar context
--   * avoid ]]/[[; this config leaves them as native section motions
--   * keep ]b/[b, ]q/[q, ]l/[l, ]a/[a native-style list navigation
--
-- See:
--   :help mapmode-o
--   :help text-objects
--   :help vim.treesitter.query.get()
--   https://github.com/nvim-treesitter/nvim-treesitter-textobjects
local modes = { "n", "x", "o" }

local function map(lhs, move_fn, captures, desc)
  vim.keymap.set(modes, lhs, function()
    require("nvim-treesitter-textobjects.move")[move_fn](captures, "textobjects")
  end, { silent = true, desc = desc })
end

return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main", -- match nvim-treesitter's 0.12-compatible main branch
  lazy = false,    -- query files must be on runtimepath before mini.ai asks for them
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        -- Direct select maps are intentionally not defined here; mini.ai owns a/i.
        -- Keep linewise defaults available for any future direct select_textobject use.
        selection_modes = {
          ["@function.outer"] = "V",
          ["@class.outer"] = "V",
          ["@conditional.outer"] = "V",
          ["@loop.outer"] = "V",
          ["@block.outer"] = "V",
        },
      },
      move = {
        set_jumps = true,
      },
    })

    -- Functions/methods: upstream convention, and matches the old IdeaVim note.
    map("]m", "goto_next_start", "@function.outer", "Next function start")
    map("[m", "goto_previous_start", "@function.outer", "Previous function start")
    map("]M", "goto_next_end", "@function.outer", "Next function end")
    map("[M", "goto_previous_end", "@function.outer", "Previous function end")

    -- Other semantic code nodes. These use free bracket slots in this config.
    map("]C", "goto_next_start", "@class.outer", "Next class/type start")
    map("[C", "goto_previous_start", "@class.outer", "Previous class/type start")
    map("]x", "goto_next_start", "@call.outer", "Next call expression")
    map("[x", "goto_previous_start", "@call.outer", "Previous call expression")
    map("]o", "goto_next_start", "@loop.outer", "Next loop")
    map("[o", "goto_previous_start", "@loop.outer", "Previous loop")
    map("]i", "goto_next_start", "@conditional.outer", "Next conditional")
    map("[i", "goto_previous_start", "@conditional.outer", "Previous conditional")
    map("]r", "goto_next_start", "@parameter.outer", "Next parameter/argument")
    map("[r", "goto_previous_start", "@parameter.outer", "Previous parameter/argument")
  end,
}
