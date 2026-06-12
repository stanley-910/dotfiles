local highlighter_filetypes = {
  "c",
  "lua",
  "vim",
  "help", -- uses the vimdoc parser; see :h vim.treesitter.language.get_lang()
  "query",
  "markdown",
}

local max_filesize = 100 * 1024 -- 100 KiB

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main", -- 0.12-compatible rewrite; master is Nvim 0.11 compatibility-only
  lazy = false,    -- upstream explicitly does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    local group = vim.api.nvim_create_augroup("config_treesitter_highlight", { clear = true })

    -- :h treesitter-highlight / :h vim.treesitter.start()
    -- nvim-treesitter main provides parsers/queries; Neovim owns starting highlight.
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = highlighter_filetypes,
      callback = function(args)
        local path = vim.api.nvim_buf_get_name(args.buf)
        local ok, stats = pcall(vim.uv.fs_stat, path)
        if ok and stats and stats.size > max_filesize then
          return
        end

        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang then
          return
        end

        local parser_ok, parser_loaded = pcall(vim.treesitter.language.add, lang)
        if parser_ok and parser_loaded then
          vim.treesitter.start(args.buf, lang)
        end
      end,
    })
  end,
}
