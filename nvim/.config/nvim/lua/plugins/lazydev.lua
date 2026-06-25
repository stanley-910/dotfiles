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

      local in_config = file == config_dir or vim.startswith(file, config_dir .. "/")
      if not in_config then
        return false
      end

      -- Respect an explicit LuaLS config inside the Neovim config if one is
      -- added later. Do not let the repo-level ~/dotfiles/.luarc.json disable
      -- LazyDev here: LuaLS currently chooses the dotfiles git root as the
      -- workspace, but this file still belongs to the Neovim config.
      if vim.uv.fs_stat(config_dir .. "/.luarc.json") or vim.uv.fs_stat(config_dir .. "/.luarc.jsonc") then
        return false
      end

      return true
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
