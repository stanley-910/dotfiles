---@type vim.lsp.Config
-- Declarative form (`:h lsp-config`): Neovim reads this off the runtimepath and merges it
-- onto nvim-lspconfig's base lsp/lua_ls.lua for us. So we write only our delta — no
-- cmd/filetypes/root_markers (lspconfig sets those), and NO `vim.lsp.config(...)` wrapper
-- (that's the imperative form, for modules that *run* like config/lsp.lua).
return {
  -- on_init runs once at client startup with the live `client`. We inject the Neovim
  -- runtime library *dynamically* (not as a static `settings` table) so we can bail out
  -- for OTHER Lua projects that ship their own .luarc.json — letting that project win
  -- instead of force-feeding it our Neovim setup.
  on_init = function(client)
    local config_dir = vim.uv.fs_realpath(vim.fn.stdpath('config'))

    if client.workspace_folders then
      local root = vim.uv.fs_realpath(client.workspace_folders[1].name)
      local root_contains_config = root
          and config_dir
          and (root == config_dir or vim.startswith(config_dir, root .. '/'))

      if
        root
        and root ~= config_dir
        and not root_contains_config
        and (vim.uv.fs_stat(root .. '/.luarc.json') or vim.uv.fs_stat(root .. '/.luarc.jsonc'))
      then
        return -- real project with its own .luarc — don't override it
      end
    end

    client.config.settings = client.config.settings or {}

    -- 'force' deep-merge keeps lspconfig's codeLens/hint and adds our keys on top.
    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua or {}, {
      runtime = {
        version = 'LuaJIT', -- Neovim embeds LuaJIT, not PUC Lua 5.x
        -- Resolve require('config.x') the way Neovim does, so go-to-definition and
        -- require-completion work against your own lua/ tree. See `:h lua-module-load`.
        path = {
          'lua/?.lua',
          'lua/?/init.lua',
        },
      },
      workspace = {
        checkThirdParty = false, -- don't prompt to set up busted/luassert/etc.
        library = {
          -- VIMRUNTIME = the Neovim Lua API stubs: what makes vim, vim.api.*, vim.fn.*
          -- resolve (and lets you delete the undefined-global band-aid in init.lua).
          vim.env.VIMRUNTIME,
          -- lspconfig's own annotations, so editing these lsp/*.lua files is typed.
          -- May be nil if lspconfig isn't loaded yet — a harmless hole in the list.
          vim.api.nvim_get_runtime_file('lua/lspconfig', false)[1],
          -- NOTE: deliberately NOT nvim_get_runtime_file('', true) (all of runtimepath):
          -- the lspconfig README warns it's far slower and misbehaves when editing your own config.
        },
      },
    })
  end,

  -- Must exist so client.config.settings.Lua is a table for tbl_deep_extend to target.
  settings = {
    Lua = {},
  },
}
