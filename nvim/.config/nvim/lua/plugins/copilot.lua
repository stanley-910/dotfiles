return {
  "zbirenbaum/copilot.lua",
  -- Load on first insert (so suggestions are ready when you start typing),
  -- on the toggle bind, or on `:Copilot ...` (e.g. `:Copilot auth`).
  event = "InsertEnter",
  cmd = "Copilot",

  opts = {
    -- No split-window panel; we only want inline ghost text.
    panel = { enabled = false },

    suggestion = {
      enabled = true,
      -- Suggest automatically as you type. Ghost text appears on its own; use
      -- Option+]/Option+[ to cycle alternatives, Option+\ to force a refresh.
      auto_trigger = true,
      -- Let the ghost text and the blink.cmp menu show at the SAME time:
      -- `false` = don't hide during completion, and we register no blink-menu
      -- autocmds, so nothing sets `copilot_suggestion_hidden`. The two UIs sit
      -- on disjoint keys (Tab / C-j / C-k / C-s for blink vs M-Tab / M-] / M-[
      -- for copilot), so their binds never collide.
      hide_during_completion = false,
      debounce = 75,
      keymap = {
        -- Option+Tab to insert. NOTE: Copilot's default accept is <M-l>, but
        -- that's already "Window right" in lua/config/keymap.lua, so we must
        -- not use it here.
        accept = "<M-Tab>",
        accept_word = false,
        accept_line = false,
        -- Cycle alternative suggestions (also forces one if none is showing).
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
        toggle_auto_trigger = false,
      },
    },

    -- Node is on PATH (v26 > the required v22), so the default "node" command
    -- and the bundled nodejs language server are fine.
    copilot_node_command = "node",
  },

  -- copilot.lua's main module is `copilot`; call setup explicitly so lazy's
  -- module inference can't bite. We intentionally register NO blink-menu
  -- autocmds: both the ghost text and the menu should be visible at once, so
  -- nothing should set `copilot_suggestion_hidden`.
  config = function(_, opts)
    require("copilot").setup(opts)
  end,

  keys = {
    -- Force a (re)fetch when nothing showed up, or nudge to the next option.
    -- Copilot has no distinct "show" vs "next" call, so this is the same action
    -- as Option+] — an ergonomic alias meaning "give me something here".
    {
      "<M-\\>",
      function() require("copilot.suggestion").next() end,
      mode = "i",
      desc = "Copilot: trigger / next suggestion",
    },
    -- Turn Copilot completion on/off for the session. When off, even the summon
    -- key does nothing and no requests are made (global teardown via
    -- copilot.command). We own `vim.g.user_copilot_off` to track state since
    -- the plugin exposes no is_enabled() getter.
    {
      "<leader>uc",
      function()
        local cmd = require("copilot.command")
        if vim.g.user_copilot_off then
          cmd.enable()
          vim.g.user_copilot_off = false
          vim.notify("Copilot: on (auto-suggests as you type)", vim.log.levels.INFO)
        else
          cmd.disable()
          vim.g.user_copilot_off = true
          vim.notify("Copilot: off", vim.log.levels.INFO)
        end
      end,
      desc = "Toggle Copilot completion",
    },
  },
}
