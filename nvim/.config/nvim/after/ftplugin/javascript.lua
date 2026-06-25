-- JavaScript projects commonly follow Prettier's two-space default.
-- Project .editorconfig files are applied after ftplugins, so they can still
-- override this buffer-local fallback when a repo declares a different style.
vim.opt_local.expandtab = true
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = -1 -- follow shiftwidth for insert-mode <Tab>/<BS>
