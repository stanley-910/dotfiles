-- LuaSnip — advanced snippet ENGINE (dynamic / choice / function nodes, etc.).
--
-- STATUS: installed but INERT. It downloads and loads, but blink.cmp still uses
-- its built-in snippet engine, so your editing is unchanged today. Nothing here
-- expands snippets until you complete the boot steps below.
--
-- ┌─ TO BOOT IT UP (do this when you're ready) ─────────────────────────────┐
-- │ 1. lua/plugins/lsp/blink.lua  → uncomment:  snippets = { preset = "luasnip" },
-- │ 2. This file → uncomment the from_lua loader in `config` below.
-- │ 3. Restart nvim (or :Lazy reload blink.cmp).
-- │ Your example snippet lives in lua/snippets/lua.lua (type `fn` in a .lua file).
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- To DISABLE entirely instead (stop it downloading): set `enabled = false`.
return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  -- Optional: enables regex-based transforms inside snippets. Needs `make` +
  -- a C toolchain. Omitted for now to keep install clean; add back if you want
  -- transform nodes:  build = "make install_jsregexp",
  event = "InsertEnter", -- loaded lazily; harmless while inert
  opts = {}
  -- BOOT STEP 2: load Lua-authored snippets from lua/snippets/<filetype>.lua
  -- require("luasnip.loaders.from_lua").load({
  --   paths = vim.fn.stdpath("config") .. "/lua/snippets",
  -- })
}
