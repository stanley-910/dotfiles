return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    -- Only attach LazyDev's LuaLS workspace-library help while editing this
    -- Neovim config. The config is stowed, so compare realpaths instead of the
    -- symlinked ~/.config/nvim path.
    enabled = function(root_dir)
      local config_dir = vim.uv.fs_realpath(vim.fn.stdpath("config"))
      local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
      local root = vim.uv.fs_realpath(root_dir)

      if not (config_dir and file and root) then
        return false
      end

      -- Respect explicit project LuaLS config if one is added later.
      if vim.uv.fs_stat(root .. "/.luarc.json") or vim.uv.fs_stat(root .. "/.luarc.jsonc") then
        return false
      end

      return file == config_dir or vim.startswith(file, config_dir .. "/")
    end,
    library = {
      -- Snacks ships Lua annotations for `Snacks`, `snacks.Config`, and picker
      -- helpers like `Snacks.picker.files()` / `Snacks.picker.lsp_symbols()`.
      "snacks.nvim",

      -- Load luv annotations only in files that mention vim.uv.
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  },
}
