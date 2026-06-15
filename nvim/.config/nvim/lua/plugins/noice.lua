-- noice.nvim — solves part 3 of the cmdheight=0 tradeoff: native cmdline
-- errors/messages no longer have a row to land in, so at cmdheight=0 they
-- trigger a blocking hit-enter prompt. noice takes over message rendering via
-- the `ext_messages` UI extension and shows them as non-blocking popups/toasts.
--
-- noice also moves the `:` command line into a floating box near the top
-- ("command mode on top"). blink.cmp (lua/plugins/lsp/blink.lua) keeps owning
-- cmdline COMPLETION: it detects noice and reads vim.g.ui_cmdline_pos to anchor
-- its menu to the popup (+ ghost text). So noice's own `popupmenu` stays OFF —
-- noice draws the input box, blink draws the completion menu. (Confirmed against
-- both projects' docs; they're designed to interoperate.)
--
-- Pairs with: cmdheight=0 + showcmdloc=statusline (lua/config/options.lua) and
-- the searchcount/recording components in lua/plugins/statusline.lua.
return {
  "folke/noice.nvim",
  enabled = true,
  event = "VeryLazy",
  -- nui.nvim is noice's required UI toolkit. nvim-notify is NOT needed: noice's
  -- "notify" view calls vim.notify, which the Snacks notifier (snacks.lua [7])
  -- already backs — so error toasts render through Snacks and show up in the
  -- <leader>n history with everything else.
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    -- noice owns the `:` command line, rendered as a floating box near the top
    -- (view = "cmdline_popup"). blink draws completions into it via ui_cmdline_pos.
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
    },
    -- OFF on purpose: blink.cmp renders cmdline/completion menus, not noice.

    popupmenu = { enabled = false },

    messages = {
      enabled = true,        -- THE point: intercept messages so cmdheight=0 never hit-enters
      view = "mini",         -- routine output (:w, yanks, etc.): transient bottom-right
      view_error = "notify", -- errors -> Snacks toast: visible + dismissable + in history
      view_warn = "notify",
      view_search = false,   -- lualine `searchcount` already renders [cur/total]
    },

    -- vim.notify() routing stays on (Snacks renders it). Long single messages
    -- open in a split instead of forcing a pager-style hit-enter.
    notify = { enabled = true },
    presets = {
      long_message_to_split = true,
      -- Keep `/` and `?` search at the bottom (familiar incsearch feel); only
      -- `:` commands pop to the top. Flip to false to make search pop too.
      bottom_search = true,
    },

    -- Keep noice OUT of LSP hover & signature. blink owns signature
    -- (blink.lua: signature.enabled), and K hover stays native. Disabling
    -- noice.hover also removes its "No information available" toast on K
    -- (that came from noice's hover with silent=false). No `override` here on
    -- purpose: with hover/signature off there's nothing for it to prettify, and
    -- leaving it out keeps native K hover fully native (uncoupled from noice).
    lsp = {
      hover = { enabled = false },
      signature = { enabled = false },
      -- basedpyright re-analyzes on every keystroke and emits a $/progress
      -- notification each time; noice's lsp.progress (on by default) rendered
      -- that as a constant stream. Off = no more per-keystroke spam. (The
      -- analysis still runs — see note below — this only silences the UI.)
      progress = { enabled = false },
    },
  },
}
