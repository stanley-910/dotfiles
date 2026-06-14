return {
  {
    "rachartier/tiny-code-action.nvim",
    event = "LspAttach",
    opts = {
      backend = "vim",

      picker = {
        "buffer",
        opts = {
          -- Enables single-key labels next to actions.
          hotkeys = true,

          -- Make hotkeys numeric first: 1,2,3,4...
          hotkeys_mode = function(titles, _used_hotkeys)
            local preferred = {
              "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
              "a", "s", "d", "f", "g", "h", "j", "k", "l",
            }

            local keys = {}
            for i = 1, #titles do
              keys[i] = preferred[i] or tostring(i)
            end
            return keys
          end,

          -- Pressing the hotkey applies the action immediately.
          auto_accept = true,

          -- Put the action picker at the cursor.
          position = "cursor",

          -- Keep preview manual at first so it doesn't obscure context.
          -- Press K inside the picker to preview.
          -- does this do anything?
          -- picker = {
          --   "snacks",
          --   opts = {
          --     layout = "vertical",
          --   },
          -- },

          auto_preview = false,

          winborder = "rounded",

          keymaps = {
            preview = "K",
            close = { "q", "<Esc>" },
            select = "<CR>",
            preview_close = { "q", "<Esc>" },
          },
        },
      },
    },
  },
}
