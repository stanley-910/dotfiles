-- colors/mine.lua — loader so :colorscheme mine works (and Snacks picker).
-- The actual spec lives in lua/theme/mine.lua. During development you
-- usually skip this and just :Lushify the spec for live preview.
vim.opt.termguicolors = true
vim.g.colors_name = "mine"
require("lush")(require("theme.mine"))
