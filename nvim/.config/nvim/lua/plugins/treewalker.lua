-- ~/.config/nvim/lua/plugins/treewalker.lua
-- Treewalker: syntax-tree-aware movement and node swapping (native Treesitter,
-- no dependencies). https://github.com/aaronik/treewalker.nvim
--
-- Keymap scheme (the plugin's own <C-h/j/k/l> defaults collide with this config:
-- <C-j>/<C-k> are 8j/8k, and insert-mode <C-h>/<C-l> are Left/Right). All eight
-- arrow combos below are unmapped elsewhere, so they are conflict-free:
--
--   Movement  = Ctrl + Arrows   -> walk the syntax tree (repeatable; Ctrl-o to undo)
--   Swapping  = Alt  + Arrows   -> move a node; mirrors Zed/VS Code "move line"
--                                  and JetBrains "move statement" muscle memory
--
-- Lazy-loads on first keypress via the `keys` table.
return {
  "aaronik/treewalker.nvim",

  -- Defaults are already tuned for intuitive movement; kept explicit here so the
  -- knobs are visible. See the Options section of the README for the full list.
  opts = {
    highlight = true,         -- briefly flash the node you land on
    highlight_duration = 250, -- ms
    highlight_group = "CursorLine",
    select = false,           -- highlight on move (true would auto-visual-select instead)
    jumplist = true,          -- movements >1 line feed the jumplist, so Ctrl-o goes back
    scope_confined = false,   -- Up/Down can climb out of the current scope when it ends
  },

  keys = {
    -- Movement (normal + visual): navigate the tree.
    { "<c-s-k>", "<cmd>Treewalker Up<cr>",    mode = { "n", "x" }, desc = "Treewalker: prev sibling" },
    { "<c-s-j>", "<cmd>Treewalker Down<cr>",  mode = { "n", "x" }, desc = "Treewalker: next sibling" },
    { "<c-s-h>", "<cmd>Treewalker Left<cr>",  mode = { "n", "x" }, desc = "Treewalker: out to parent" },
    { "<c-s-l>", "<cmd>Treewalker Right<cr>", mode = { "n", "x" }, desc = "Treewalker: in to child" },

    -- Swapping (normal): move the node under the cursor.
    -- Up/Down are linewise and carry comments/decorators; Left/Right are nodewise
    -- (function args, list elements, enum members).
    -- { "<M-Up>",    "<cmd>Treewalker SwapUp<cr>",    desc = "Treewalker: swap node up" },
    -- { "<M-Down>",  "<cmd>Treewalker SwapDown<cr>",  desc = "Treewalker: swap node down" },
    -- { "<M-Left>",  "<cmd>Treewalker SwapLeft<cr>",  desc = "Treewalker: swap node left" },
    -- { "<M-Right>", "<cmd>Treewalker SwapRight<cr>", desc = "Treewalker: swap node right" },
  },
}
