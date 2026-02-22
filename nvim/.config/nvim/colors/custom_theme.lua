-- Neovim colorscheme generated from zed/.config/zed/themes/custom-theme.json

if vim.g.colors_name then
  vim.cmd("hi clear")
end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "custom_theme"

local c = {
  bg = "#0f0f12", -- editor.background
  surface = "#202024", -- background / surface.background
  element = "#393941", -- element.background / border.variant
  border = "#505058", -- border

  fg = "#ffffff", -- editor.foreground / text
  muted = "#d0d0d2", -- text.muted / text.accent
  accent = "#ffae49", -- accent (used for string delimiters)
  placeholder = "#808086", -- text.placeholder / editor.line_number

  success = "#30df81",
  warning = "#ffae49",
  error = "#fe303a",
  info = "#02a9ff",

  yellow = "#fff556",
  magenta = "#d559ff",
  cyan = "#00f3ff",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(from, to)
  hi(from, { link = to })
end

-- UI
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalNC", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.surface })
hi("FloatBorder", { fg = c.border, bg = c.surface })
hi("FloatTitle", { fg = c.muted, bg = c.surface, bold = true })

hi("ColorColumn", { bg = c.surface })
hi("CursorLine", { bg = c.surface })
hi("CursorColumn", { bg = c.surface })
hi("CursorLineNr", { fg = c.fg, bold = true })
hi("LineNr", { fg = c.placeholder })
hi("SignColumn", { fg = c.placeholder, bg = c.bg })
hi("FoldColumn", { fg = c.placeholder, bg = c.bg })
hi("Folded", { fg = c.placeholder, bg = c.surface })

hi("VertSplit", { fg = c.border, bg = c.bg })
hi("WinSeparator", { fg = c.border, bg = c.bg })
hi("StatusLine", { fg = c.muted, bg = c.surface })
hi("StatusLineNC", { fg = c.placeholder, bg = c.surface })
hi("TabLine", { fg = c.placeholder, bg = c.surface })
hi("TabLineFill", { fg = c.placeholder, bg = c.surface })
hi("TabLineSel", { fg = c.fg, bg = c.bg, bold = true })

hi("Pmenu", { fg = c.fg, bg = c.element })
hi("PmenuSel", { fg = c.fg, bg = c.surface })
hi("PmenuSbar", { bg = c.element })
hi("PmenuThumb", { bg = c.border })

hi("Visual", { bg = c.element })
hi("Search", { fg = c.bg, bg = c.warning })
hi("IncSearch", { fg = c.bg, bg = c.yellow })
hi("CurSearch", { fg = c.bg, bg = c.yellow })
hi("MatchParen", { fg = c.fg, bg = c.element, bold = true })

hi("Directory", { fg = c.info })
hi("Title", { fg = c.fg, bold = true })
hi("NonText", { fg = c.element })
hi("Whitespace", { fg = c.element })
hi("SpecialKey", { fg = c.element })

hi("ErrorMsg", { fg = c.error, bold = true })
hi("WarningMsg", { fg = c.warning, bold = true })
hi("MoreMsg", { fg = c.info })
hi("ModeMsg", { fg = c.muted })
hi("Question", { fg = c.info, bold = true })

hi("DiffAdd", { fg = c.success, bg = c.surface })
hi("DiffChange", { fg = c.warning, bg = c.surface })
hi("DiffDelete", { fg = c.error, bg = c.surface })
hi("DiffText", { fg = c.fg, bg = c.element, bold = true })

hi("SpellBad", { sp = c.error, undercurl = true })
hi("SpellCap", { sp = c.info, undercurl = true })
hi("SpellLocal", { sp = c.warning, undercurl = true })
hi("SpellRare", { sp = c.magenta, undercurl = true })

-- Base syntax
hi("Comment", { fg = c.placeholder, italic = true })
hi("Constant", { fg = c.warning })
hi("String", { fg = c.warning })
hi("Character", { fg = c.warning })
hi("Number", { fg = c.warning })
hi("Boolean", { fg = c.warning, bold = true })
hi("Float", { fg = c.warning })

hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.fg, italic = true })

hi("Statement", { fg = c.fg, bold = true })
hi("Conditional", { fg = c.fg, bold = true })
hi("Repeat", { fg = c.fg, bold = true })
hi("Label", { fg = c.fg, bold = true })
hi("Operator", { fg = c.placeholder })
hi("Keyword", { fg = c.fg, bold = true })
hi("Exception", { fg = c.fg, bold = true })

hi("PreProc", { fg = c.fg, bold = true })
hi("Include", { fg = c.fg, bold = true })
hi("Define", { fg = c.fg, bold = true })
hi("Macro", { fg = c.fg, bold = true })
hi("PreCondit", { fg = c.fg, bold = true })

hi("Type", { fg = c.fg, bold = true })
hi("StorageClass", { fg = c.fg, bold = true })
hi("Structure", { fg = c.fg, bold = true })
hi("Typedef", { fg = c.fg, bold = true })

hi("Special", { fg = c.placeholder })
hi("SpecialChar", { fg = c.warning, bold = true })
hi("Tag", { fg = c.fg, bold = true })
hi("Delimiter", { fg = c.placeholder })
hi("SpecialComment", { fg = c.placeholder, italic = true })
hi("Debug", { fg = c.error })

hi("Underlined", { underline = true })
hi("Ignore", { fg = c.placeholder })
hi("Error", { fg = c.error, bold = true })
hi("Todo", { fg = c.bg, bg = c.warning, bold = true })

-- Treesitter (new-style @ captures)
link("@comment", "Comment")
link("@punctuation", "Delimiter")
link("@punctuation.delimiter", "Delimiter")
link("@punctuation.bracket", "Delimiter")
hi("@punctuation.special", { fg = c.accent })

hi("@operator", { fg = c.placeholder })
hi("@keyword", { fg = c.fg, bold = true })
hi("@keyword.operator", { fg = c.placeholder })
hi("@keyword.function", { fg = c.fg, bold = true })
hi("@keyword.return", { fg = c.fg, bold = true })
hi("@keyword.import", { fg = c.fg, bold = true })

hi("@function", { fg = c.fg, italic = true })
hi("@function.builtin", { fg = c.fg, italic = true })
hi("@function.method", { fg = c.fg, italic = true })
hi("@function.call", { fg = c.fg, italic = true })
hi("@method", { fg = c.fg, italic = true })
hi("@method.call", { fg = c.fg, italic = true })

hi("@type", { fg = c.fg, bold = true })
hi("@type.builtin", { fg = c.fg, bold = true })
hi("@tag", { fg = c.fg, bold = true })
hi("@tag.attribute", { fg = c.fg, bold = true })
hi("@attribute", { fg = c.fg, bold = true })

hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.fg, bold = true })
hi("@property", { fg = c.fg })

hi("@string", { fg = c.warning })
hi("@string.delimiter", { fg = c.accent })
hi("@string.escape", { fg = c.warning, bold = true })
hi("@string.special", { fg = c.warning, bold = true })
hi("@number", { fg = c.warning })
hi("@boolean", { fg = c.warning, bold = true })
hi("@constant", { fg = c.warning })
hi("@constant.builtin", { fg = c.warning, bold = true })

-- LSP / diagnostics
hi("DiagnosticError", { fg = c.error })
hi("DiagnosticWarn", { fg = c.warning })
hi("DiagnosticInfo", { fg = c.info })
hi("DiagnosticHint", { fg = c.cyan })

hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.surface })
hi("DiagnosticVirtualTextWarn", { fg = c.warning, bg = c.surface })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.surface })
hi("DiagnosticVirtualTextHint", { fg = c.cyan, bg = c.surface })

hi("DiagnosticUnderlineError", { sp = c.error, undercurl = true })
hi("DiagnosticUnderlineWarn", { sp = c.warning, undercurl = true })
hi("DiagnosticUnderlineInfo", { sp = c.info, undercurl = true })
hi("DiagnosticUnderlineHint", { sp = c.cyan, undercurl = true })

hi("DiagnosticSignError", { fg = c.error, bg = c.bg })
hi("DiagnosticSignWarn", { fg = c.warning, bg = c.bg })
hi("DiagnosticSignInfo", { fg = c.info, bg = c.bg })
hi("DiagnosticSignHint", { fg = c.cyan, bg = c.bg })

hi("LspReferenceText", { bg = c.element })
hi("LspReferenceRead", { bg = c.element })
hi("LspReferenceWrite", { bg = c.warning })

-- Git signs (common group names)
hi("GitSignsAdd", { fg = c.success })
hi("GitSignsChange", { fg = c.warning })
hi("GitSignsDelete", { fg = c.error })

-- Legacy Treesitter group names (some plugins/queries still use these)
hi("TSStringDelimiter", { fg = c.accent })

-- Vim built-in syntax groups (not Treesitter), e.g. `syntax/sh.vim`
-- In shell scripts, the *quote characters* themselves are `shQuote` (often linked to `shOperator`).
hi("shQuote", { fg = c.accent })

-- Shell: command substitution + test operators
-- Swap the emphasis: delimiters like `$(` / `)` should look like `[[` / `]]`,
-- while the command inside `$()` should look like `if`.
link("shCmdSubRegion", "Delimiter") -- `$(` and `)` in `$(...)`
link("shTestOpr", "Delimiter") -- e.g. `-f`, `-z`, etc.
link("shCommandSub", "Conditional") -- contents inside `$(...)` when not otherwise classified
link("shOption", "Conditional") -- e.g. `-m` in `uname -m`

-- -- Terminal palette (matches Zed terminal.ansi.*)
-- vim.g.terminal_color_0 = c.bg
-- vim.g.terminal_color_1 = c.error
-- vim.g.terminal_color_2 = c.success
-- vim.g.terminal_color_3 = c.yellow
-- vim.g.terminal_color_4 = c.info
-- vim.g.terminal_color_5 = c.magenta
-- vim.g.terminal_color_6 = c.cyan
-- vim.g.terminal_color_7 = c.placeholder
-- vim.g.terminal_color_8 = c.placeholder
-- vim.g.terminal_color_9 = c.error
-- vim.g.terminal_color_10 = c.success
-- vim.g.terminal_color_11 = c.yellow
-- vim.g.terminal_color_12 = c.info
-- vim.g.terminal_color_13 = c.magenta
-- vim.g.terminal_color_14 = c.cyan
-- vim.g.terminal_color_15 = c.fg

