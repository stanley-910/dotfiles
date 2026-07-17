-- ~/.config/nvim/lua/plugins/treewalker.lua
-- Treewalker: syntax-tree-aware movement and node swapping (native Treesitter,
-- no dependencies). https://github.com/aaronik/treewalker.nvim
--
-- Keymap scheme (the plugin's own <C-h/j/k/l> defaults collide with this config:
-- <C-j>/<C-k> are 8j/8k, and insert-mode <C-h>/<C-l> are Left/Right). Shifted
-- Ctrl-h/j/k/l is reserved for seamless Neovim-window/tmux-pane navigation.
--
--   Movement  = Alt + Shift + h/j/k/l -> walk the syntax tree (repeatable; Ctrl-o to undo)
--   Swapping  = Alt + Arrows          -> move a node; mirrors Zed/VS Code "move line"
--                                       and JetBrains "move statement" muscle memory
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
    { "<M-K>", "<cmd>Treewalker Up<cr>",    mode = { "n", "x" }, desc = "Treewalker: prev sibling" },
    { "<M-J>", "<cmd>Treewalker Down<cr>",  mode = { "n", "x" }, desc = "Treewalker: next sibling" },
    { "<M-H>", "<cmd>Treewalker Left<cr>",  mode = { "n", "x" }, desc = "Treewalker: out to parent" },
    { "<M-L>", "<cmd>Treewalker Right<cr>", mode = { "n", "x" }, desc = "Treewalker: in to child" },

    -- Swapping (normal): move the node under the cursor.
    -- Up/Down are linewise and carry comments/decorators; Left/Right are nodewise
    -- (function args, list elements, enum members).
    -- { "<M-Up>",    "<cmd>Treewalker SwapUp<cr>",    desc = "Treewalker: swap node up" },
    -- { "<M-Down>",  "<cmd>Treewalker SwapDown<cr>",  desc = "Treewalker: swap node down" },
    -- { "<M-Left>",  "<cmd>Treewalker SwapLeft<cr>",  desc = "Treewalker: swap node left" },
    -- { "<M-Right>", "<cmd>Treewalker SwapRight<cr>", desc = "Treewalker: swap node right" },
  },
}
