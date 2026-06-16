--
-- mine.lua — a Lush colorscheme spec (dark)
-- ---------------------------------------------------------------------------
-- WORKFLOW
--   1. :e this file, then run  :Lushify   (live preview turns on)
--   2. Pick anchor colors with minty:  <leader>uH (:Huefy) → copy hex
--      Explore shades with:            <leader>uS (:Shades)
--   3. Paste hex into the PALETTE block below as hsl("#rrggbb").
--      Tune the ~25 BASE groups — every linked group downstream follows.
--   4. When happy, :colorscheme mine   (loads via colors/mine.lua)
--
-- THREE MECHANICS
--   Base   : Foo { fg = palette.x }          -- carries real color
--   Link   : Bar { Foo }                      -- name only → :hi link (follows Foo)
--   Inherit: Baz { Foo, fg = Foo.fg.li(20) }  -- copy + override (NEW color)
--
-- The placeholder palette below is intentionally bland so the file LOADS and
-- :Lushify works on first run. Replace every value flagged << REPLACE >>.
-- ---------------------------------------------------------------------------

local lush = require("lush")
local hsl = lush.hsl

return lush(function(injected_functions)
  local sym     = injected_functions.sym

  -- ══ PALETTE ════════════════════════════════════════════════════════════
  -- Name colors by ROLE, not hue. Anchor these 8-10 with :Huefy, then DERIVE
  -- the rest with .li()/.da()/.sa()/.de()/.ro() instead of hand-picking.
  local bg      = hsl("#0a0a0d")   -- << REPLACE >> editor background
  local fg      = hsl("#dcd7ba")   -- << REPLACE >> default foreground
  local bg_dim  = bg.da(20)        -- darker bg (gutters, float)
  local bg_lite = bg.li(8)         -- lighter bg (cursorline, selection base)
  local muted   = fg.da(45).de(20) -- comments / non-text (low contrast on purpose)
  local sel     = hsl("#223249")   -- << REPLACE >> visual selection bg

  -- accents — anchor with :Huefy, keep saturation modest for large areas
  local red     = hsl("#e46876") -- << REPLACE >> errors
  local orange  = hsl("#ffa066") -- << REPLACE >> constants / numbers
  local yellow  = hsl("#e6c384") -- << REPLACE >> warnings
  local green   = hsl("#98bb6c") -- << REPLACE >> strings
  local teal    = hsl("#7aa89f") -- << REPLACE >> types
  local blue    = hsl("#7e9cd8") -- << REPLACE >> functions
  local purple  = hsl("#957fb8") -- << REPLACE >> keywords
  local cyan    = hsl("#7fb4ca") -- << REPLACE >> specials / operators

  return {
    -- ══ EDITOR / UI (base) ═══════════════════════════════════════════════
    Normal { fg = fg, bg = bg },
    NormalFloat { fg = fg, bg = bg_dim },
    FloatBorder { fg = muted, bg = bg_dim },
    FloatTitle { fg = blue, bg = bg_dim, gui = "bold" },
    ColorColumn { bg = bg_lite },
    Cursor { fg = bg, bg = fg },
    CursorLine { bg = bg_lite },
    CursorColumn { CursorLine },
    LineNr { fg = muted.da(15), bg = bg_dim },
    CursorLineNr { fg = yellow, bg = bg_dim, gui = "bold" },
    SignColumn { bg = bg_dim },
    FoldColumn { fg = muted, bg = bg_dim },
    Folded { fg = muted, bg = bg_lite },
    Visual { bg = sel },
    VisualNOS { Visual },
    Search { fg = bg, bg = yellow },
    IncSearch { fg = bg, bg = orange, gui = "bold" },
    CurSearch { IncSearch },
    MatchParen { fg = cyan, gui = "bold" },
    NonText { fg = muted.da(25) },
    Whitespace { NonText },
    EndOfBuffer { fg = bg },
    Conceal { fg = muted },
    Title { fg = blue, gui = "bold" },
    Directory { fg = blue },
    WinSeparator { fg = bg_lite },
    VertSplit { WinSeparator },
    StatusLine { fg = fg, bg = bg_lite },
    StatusLineNC { fg = muted, bg = bg_dim },
    Pmenu { fg = fg, bg = bg_dim },
    PmenuSel { fg = bg, bg = blue },
    PmenuSbar { bg = bg_lite },
    PmenuThumb { bg = muted },
    WildMenu { PmenuSel },
    QuickFixLine { bg = sel },
    ErrorMsg { fg = red },
    WarningMsg { fg = yellow },
    ModeMsg { fg = fg, gui = "bold" },
    MoreMsg { fg = green },
    Question { fg = green },
    SpecialKey { fg = muted },

    -- ══ SYNTAX (base — the color-bearing roots) ══════════════════════════
    Comment { fg = muted, gui = "italic" },
    Constant { fg = orange },
    String { fg = green },
    Character { String },
    Number { fg = orange },
    Boolean { fg = orange },
    Float { Number },
    Identifier { fg = fg },
    Function { fg = blue },
    Statement { fg = purple },
    Conditional { Statement },
    Repeat { Statement },
    Label { Statement },
    Exception { Statement },
    Operator { fg = cyan },
    Keyword { fg = purple, gui = "italic" },
    PreProc { fg = cyan },
    Include { PreProc },
    Define { PreProc },
    Macro { PreProc },
    PreCondit { PreProc },
    Type { fg = teal },
    StorageClass { Type },
    Structure { Type },
    Typedef { Type },
    Special { fg = cyan },
    SpecialChar { Special },
    Tag { Special },
    Delimiter { fg = fg.da(15) },
    SpecialComment { Comment },
    Debug { Special },
    Underlined { fg = blue, gui = "underline" },
    Bold { gui = "bold" },
    Italic { gui = "italic" },
    Ignore { fg = muted },
    Error { fg = red, gui = "bold" },
    Todo { fg = bg, bg = yellow, gui = "bold" },

    -- ══ DIAGNOSTICS (base) ═══════════════════════════════════════════════
    DiagnosticError { fg = red },
    DiagnosticWarn { fg = yellow },
    DiagnosticInfo { fg = blue },
    DiagnosticHint { fg = teal },
    DiagnosticOk { fg = green },
    DiagnosticUnderlineError { gui = "undercurl", sp = red },
    DiagnosticUnderlineWarn { gui = "undercurl", sp = yellow },
    DiagnosticUnderlineInfo { gui = "undercurl", sp = blue },
    DiagnosticUnderlineHint { gui = "undercurl", sp = teal },

    -- ══ DIFF / GIT (base) ════════════════════════════════════════════════
    DiffAdd { bg = green.da(50).de(30) },
    DiffChange { bg = blue.da(55).de(35) },
    DiffDelete { bg = red.da(55).de(35) },
    DiffText { bg = blue.da(40).de(20) },
    Added { fg = green },
    Changed { fg = blue },
    Removed { fg = red },

    -- ══ TREESITTER LINKS ═════════════════════════════════════════════════
    -- Lifted from the kanagawa dump: change a BASE group above and every one
    -- of these follows. Add/break links here to make a token diverge.
    sym "@comment" { Comment },
    sym "@comment.todo" { Todo },
    sym "@constant" { Constant },
    sym "@constant.builtin" { Special },
    sym "@constant.macro" { Macro },
    sym "@string" { String },
    sym "@string.escape" { SpecialChar },
    sym "@string.special" { SpecialChar },
    sym "@character" { Character },
    sym "@number" { Number },
    sym "@number.float" { Float },
    sym "@boolean" { Boolean },
    sym "@function" { Function },
    sym "@function.builtin" { Special },
    sym "@function.macro" { Macro },
    sym "@function.method" { Function },
    sym "@constructor" { Special },
    sym "@keyword" { Keyword },
    sym "@keyword.function" { Keyword },
    sym "@keyword.return" { Keyword },
    sym "@keyword.import" { PreProc },
    sym "@keyword.operator" { Operator },
    sym "@keyword.exception" { Exception },
    sym "@conditional" { Conditional },
    sym "@repeat" { Repeat },
    sym "@label" { Label },
    sym "@operator" { Operator },
    sym "@type" { Type },
    sym "@type.builtin" { Special },
    sym "@type.qualifier" { Keyword },
    sym "@attribute" { Constant },
    sym "@property" { Identifier },
    sym "@field" { Identifier },
    sym "@variable" { Identifier },
    sym "@variable.builtin" { Special },
    sym "@variable.parameter" { fg = fg.li(5) },
    sym "@module" { Structure },
    sym "@namespace" { Structure },
    sym "@punctuation" { Delimiter },
    sym "@punctuation.bracket" { Delimiter },
    sym "@punctuation.delimiter" { Delimiter },
    sym "@tag" { Tag },
    sym "@tag.attribute" { Identifier },
    sym "@tag.delimiter" { Delimiter },

    -- ══ MARKUP (markdown / docs) ═════════════════════════════════════════
    sym "@markup.heading" { fg = blue, gui = "bold" },
    sym "@markup.raw" { String },
    sym "@markup.link" { Underlined },
    sym "@markup.link.url" { fg = cyan, gui = "underline" },
    sym "@markup.list" { fg = purple },
    sym "@markup.strong" { gui = "bold" },
    sym "@markup.italic" { gui = "italic" },
    sym "@markup.quote" { Comment },

    -- ══ LSP SEMANTIC TOKENS (a few that benefit from explicit links) ═════
    sym "@lsp.type.namespace" { sym "@module" },
    sym "@lsp.type.function" { sym "@function" },
    sym "@lsp.type.method" { sym "@function.method" },
    sym "@lsp.type.property" { sym "@property" },
    sym "@lsp.type.variable" { sym "@variable" },
    sym "@lsp.type.parameter" { sym "@variable.parameter" },
    sym "@lsp.type.keyword" { sym "@keyword" },
    sym "@lsp.type.enum" { sym "@type" },
    sym "@lsp.type.struct" { sym "@type" },
    sym "@lsp.type.interface" { sym "@type" },
    sym "@lsp.mod.deprecated" { gui = "strikethrough" },
  }
end)
