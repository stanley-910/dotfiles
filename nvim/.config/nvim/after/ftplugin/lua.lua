-- Lua style for Neovim config/plugins: two-space indentation with spaces.
-- This file is sourced after Neovim's built-in Lua ftplugin, so it is a small
-- filetype-specific patch rather than a replacement for runtime defaults.
vim.opt_local.expandtab = true
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = -1 -- follow shiftwidth for insert-mode <Tab>/<BS>
