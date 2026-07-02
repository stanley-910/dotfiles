local highlighter_filetypes = {
  "c",
  "javascript",
  "javascriptreact",
  "lua",
  "vim",
  "help", -- uses the vimdoc parser; see :h vim.treesitter.language.get_lang()
  "query",
  "markdown",
  "python",
  "typescript",
  "typescriptreact",
  "bash",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "java"
}

-- Parsers to install. The `main` branch dropped master's declarative
-- `ensure_installed` field, so this is an imperative install() call in config()
-- below. These are PARSER names, which differ from the filetypes above:
--   * the `help` filetype highlights with the `vimdoc` parser
--   * `markdown` needs its `markdown_inline` sibling for fenced code blocks
-- Neovim 0.12 ships equivalents bundled, but nvim-treesitter's get_installed()
-- only counts parsers in ITS OWN install dir -- not Neovim's runtime -- so on
-- first launch it downloads its own version-matched copies (desirable: the
-- plugin's queries are written against the plugin's parser versions). After
-- that the install() below is a true no-op until the list changes. To add a
-- language, add it here AND to highlighter_filetypes above; discover names with
-- `:TSInstall <Tab>` or `:lua =require("nvim-treesitter").get_available()`.
local ensure_installed = {
  "c",
  "javascript",
  "lua",
  "vim",
  "vimdoc", -- parser for the `help` filetype
  "query",
  "markdown",
  "markdown_inline", -- fenced code blocks inside markdown
  "python",
  "tsx",             -- parser for the `typescriptreact` filetype
  "typescript",
  "bash",

  -- go has multiple parsers for its multiple filetypes
  "go",
  "gomod",
  "gosum",
  "gowork",
  "java"


}

local max_filesize = 100 * 1024 -- 100 KiB

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main", -- 0.12-compatible rewrite; master is Nvim 0.11 compatibility-only
  lazy = false,    -- upstream explicitly does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    -- ensure_installed equivalent: install only the parsers we are missing so
    -- this does not recompile everything on every startup. install() is async
    -- (fire-and-forget); get_installed() reports what is already on disk.
    local ts = require("nvim-treesitter")
    local installed = ts.get_installed("parsers")
    local missing = vim.tbl_filter(function(lang)
      return not vim.tbl_contains(installed, lang)
    end, ensure_installed)
    if #missing > 0 then
      ts.install(missing)
    end

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
