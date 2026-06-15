-- Print the line number in front of each line
vim.opt.number = true

-- Use relative line numbers, so that it is easier to jump with j, k. This will affect the 'number'
-- option above, see `:h number_relativenumber`
vim.opt.relativenumber = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Highlight the line where the cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Show <tab> and trailing spaces
vim.opt.list = true

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s) See `:help 'confirm'`
vim.opt.confirm = true



vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.showmode = false -- lualine already shows the current mode

-- Default indentation policy for buffers that do not have a stronger filetype
-- opinion. Filetype plugins may override this, and after/ftplugin/* files are
-- where we put our explicit per-language patches.
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = -1 -- follow shiftwidth for insert-mode <Tab>/<BS>

-- Keep search highlighting enabled globally. `:nohlsearch` only hides the
-- current highlights until the next `/`, `?`, `n`, or `N` search.
vim.opt.hlsearch = true

-- anticipate more signcolumn space for plugins, 'auto' is jittery, so add one more
vim.opt.signcolumn = "yes"

vim.opt.wrap = false

vim.opt.undofile = true -- save undotree per file after writing

vim.opt.cmdheight = 0 -- reclaim the bottom row; cmdline appears only while typing : or /

-- With cmdheight=0 there is no cmdline row to host the "showcmd" area (pending
-- operators / partial commands like d, 3, "a). Route it into the statusline
-- instead, where lualine renders it via the `%S` item. See :help 'showcmdloc'.
vim.opt.showcmdloc = "statusline"
