return {
  "Bekaboo/dropbar.nvim",
  -- dropbar.nvim already lazy-attaches its winbar on FileType/LspAttach events;
  -- loading the plugin itself from a keymap is too late for that setup path and
  -- leaves _G.dropbar nil when calling dropbar.api directly.
  lazy = false,
  opts = {
    bar = {
      sources = function(buf, _)
        local sources = require("dropbar.sources")
        local utils = require("dropbar.utils")

        if vim.bo[buf].ft == "markdown" then
          return {
            sources.path,
            sources.markdown,
          }
        end

        if vim.bo[buf].buftype == "terminal" then
          return {
            sources.terminal,
          }
        end

        return {
          -- Show only the file name from the path source, then semantic context.
          -- See :help dropbar-options and :help dropbar-path.
          sources.path,
          utils.source.fallback({
            sources.lsp,
            sources.treesitter,
          }),
        }
      end,
    },
    sources = {
      path = {
        max_depth = 1,
      },
    },
  },
  keys = {
    {
      "<leader>;",
      function()
        require("dropbar.api").pick()
      end,
      desc = "Pick symbols in winbar",
    },
    {
      "[;",
      function()
        require("dropbar.api").goto_context_start()
      end,
      desc = "Go to start of current context",
    },
    {
      "];",
      function()
        require("dropbar.api").select_next_context()
      end,
      desc = "Select next context",
    },
  },
}
