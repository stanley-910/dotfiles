return {
  "Bekaboo/dropbar.nvim",
  -- dropbar.nvim already lazy-attaches its winbar on FileType/LspAttach events;
  -- loading the plugin itself from a keymap is too late for that setup path and
  -- leaves _G.dropbar nil when calling dropbar.api directly.
  lazy = false,
  dependencies = {
    {
      -- dropbar uses telescope-fzf-native as a standalone fuzzy engine; this
      -- does not require keeping telescope.nvim itself installed.
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  config = function()
    require("dropbar").setup()

    local dropbar_api = require("dropbar.api")
    vim.keymap.set("n", "<leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
    vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
    vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
  end,
}
