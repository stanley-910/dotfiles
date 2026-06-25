-- ~/.config/nvim/lua/plugins/leetcode.lua
-- leetcode.nvim: solve LeetCode problems inside Neovim.
-- Full option types: https://github.com/kawre/leetcode.nvim/blob/master/lua/leetcode/config/template.lua
--
-- Launch maps live in the lazy `keys` table below (the trouble.nvim pattern in
-- this config), so the plugin lazy-loads on first use. In-question keys (q,
-- <CR>, r, U, H, L) are buffer-local inside leetcode windows, so they do not
-- collide with the global maps in lua/config/keymap.lua.
return {
  "kawre/leetcode.nvim",

  -- Lazy-load on the :Leet command. NOTE: choosing cmd-based loading disables
  -- the alternative `arg` launch method (opening nvim with `nvim leetcode.nvim`).
  cmd = "Leet",

  -- The question description is formatted with the tree-sitter-html parser.
  -- nvim-treesitter here is on the `main` branch, where :TSUpdate only refreshes
  -- already-installed parsers, so use :TSInstall to guarantee html is present.
  build = ":TSInstall html",

  dependencies = {
    "nvim-lua/plenary.nvim", -- required: core utilities
    "MunifTanjim/nui.nvim",  -- required: UI components
    "folke/snacks.nvim",     -- picker provider
    "nvim-tree/nvim-web-devicons"
  },

  ---@type lc.UserConfig
  opts = {
    -- Solving language. Switch per-question at runtime with :Leet lang.
    lang = "python3",

    -- Reuse the existing Snacks picker install for problem/tab/lang pickers.
    picker = { provider = "snacks-picker" },

    -- Standalone mode (the default) wants to own the whole Neovim session and
    -- refuses to start when listed buffers exist ("contains listed buffers").
    -- We launch :Leet mid-session via keymaps, so run non-standalone. Exit the
    -- dashboard with :Leet exit.
    plugins = { non_standalone = true },

    -- Everything below is the plugin's own sensible default, kept explicit so
    -- it is easy to tweak later:
    --   editor.reset_previous_code = true   -- reset code when switching questions
    --   editor.fold_imports        = true   -- fold the injected imports block
    --   console.open_on_runcode    = true   -- pop the console open on :Leet run
    --   description.position        = "left"
    --   image_support               = false  -- needs 3rd/image.nvim; renders text otherwise

    -- Per-language code injection (imports / boilerplate). Uncomment to use:
    -- injector = {
    --   ["python3"] = {
    --     before = { "from typing import List, Optional" },
    --   },
    -- },
  },

  -- <leader>p = plugins group, l = leetcode. Descriptions surface in which-key.
  -- NOTE: the dashboard map is bare `:Leet`. leetcode registers `:Leet` in two
  -- stages: a no-arg bootstrap command that opens the dashboard, which then
  -- swaps in the real `nargs="?"` command. Subcommands (menu/run/submit/...)
  -- only exist *after* the dashboard has opened once, so the launch map must be
  -- bare `:Leet` or it throws E488. The rest are used inside an open question.
  keys = {
    { "<leader>pll", "<cmd>Leet<cr>",         desc = "LeetCode: dashboard" },
    { "<leader>plr", "<cmd>Leet run<cr>",     desc = "LeetCode: run" },
    { "<leader>pls", "<cmd>Leet submit<cr>",  desc = "LeetCode: submit" },
    { "<leader>plc", "<cmd>Leet console<cr>", desc = "LeetCode: console" },
    { "<leader>pld", "<cmd>Leet daily<cr>",   desc = "LeetCode: daily question" },
    { "<leader>plL", "<cmd>Leet lang<cr>",    desc = "LeetCode: switch language" },
  },
}
