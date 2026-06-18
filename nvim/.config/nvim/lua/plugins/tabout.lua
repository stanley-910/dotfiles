return {
  {
    "nvim-mini/mini.keymap",
    version = "*",
    lazy = false,
    config = function()
      local keymap = require("mini.keymap")
      local map_multistep = keymap.map_multistep

      -- Keep <Tab> as a single orchestration layer instead of letting Blink,
      -- snippets, tabout, and indentation each compete for their own mapping.
      local blink_select_and_accept = {
        condition = function()
          local ok, blink = pcall(require, "blink.cmp")
          return ok and blink.is_visible()
        end,
        action = function()
          return function()
            require("blink.cmp").select_and_accept()
          end
        end,
      }

      map_multistep({ "i", "s" }, "<Tab>", {
        blink_select_and_accept,
        "luasnip_next",
        "jump_after_tsnode",
        "jump_after_close",
        "increase_indent",
      })

      map_multistep({ "i", "s" }, "<S-Tab>", {
        "luasnip_prev",
        "jump_before_tsnode",
        "jump_before_open",
        "decrease_indent",
      })
    end,
  },
}
