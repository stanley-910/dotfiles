-- LuaSnip — advanced snippet ENGINE (dynamic / choice / function nodes, etc.).
--
-- Blink routes snippet expansion here (see lua/plugins/lsp/blink.lua), and this
-- file loads both friendly-snippets and Lua-authored snippets from
-- lua/snippets/<filetype>.lua.
--
-- To DISABLE entirely instead (stop it downloading): set `enabled = false`.
return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  dependencies = { "rafamadriz/friendly-snippets" },
  -- Optional: enables regex-based transforms inside snippets. Needs `make` +
  -- a C toolchain. Omitted for now to keep install clean; add back if you want
  -- transform nodes:  build = "make install_jsregexp",
  event = "InsertEnter",
  opts = {},
  -- `config` is needed for loader side effects; plain LuaSnip settings still go
  -- in `opts` above so lazy.nvim's setup contract stays explicit.
  config = function(_, opts)
    require("luasnip").setup(opts)

    -- Keep VSCode-format friendly-snippets available after switching blink.cmp
    -- from Neovim's built-in snippet engine to LuaSnip.
    require("luasnip.loaders.from_vscode").lazy_load()

    -- Load Lua-authored snippets from lua/snippets/<filetype>.lua.
    require("luasnip.loaders.from_lua").load({
      paths = vim.fn.stdpath("config") .. "/lua/snippets",
    })
  end,
}
