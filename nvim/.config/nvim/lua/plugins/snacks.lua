-- snacks.nvim — folke's collection of small QoL plugins, each independently
-- toggleable. This is a META-plugin: the repo ships ~25 "snacks" (bigfile,
-- words, scroll, notifier, picker, dashboard, ...) and NONE are active unless
-- you opt in with `<module> = { enabled = true }` in `opts` below.
--
-- Workflow here: enable ONE snack at a time, smallest scope first, tune it,
-- then move to the next. Keep this file as the running ledger of what's on.
--
-- lazy = false + priority = 1000: snacks wants to load early (some modules hook
-- very-early events like bigfile/quickfile), so it is not lazy-loaded. This is
-- folke's documented recommendation.
--
-- KNOWN OVERLAPS with the current config — do NOT enable these without a plan:
--   indent     -> already have lua/plugins/indent.lua
--   picker     -> telescope still owns files/grep; Snacks picker is enabled
--                 only for curated symbol navigation.
--   statuscolumn, notifier, input, explorer -> larger scope,
--                 some overlap dropbar/statusline; revisit later.
--
-- See: https://github.com/folke/snacks.nvim  (per-module docs under /docs)
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- Enable snacks one at a time, smallest scope first.
    --
    -- [1] bigfile: tags oversized buffers with filetype `bigfile`, which stops
    -- LSP + Treesitter from attaching and disables matchparen/completion so
    -- huge/minified files stay responsive. Layers with treesitter.lua's 100 KiB
    -- highlight cap (that skips highlighting; this also blocks LSP attach).
    -- Knobs (defaults shown) — tweak to taste:
    bigfile = {
      enabled = true,
      notify = true,            -- toast when big-file mode kicks in
      size = 1.5 * 1024 * 1024, -- trigger above 1.5 MB
      line_length = 1000,       -- or if average line length exceeds this (minified files)
    },

    -- [2] words: auto-highlights all LSP references of the symbol under the
    -- cursor. It exposes Snacks.words.jump(), but this config intentionally does
    -- not map it; ]] / [[ remain native section motions unless mapped elsewhere.
    -- Needs an attached LSP that supports textDocument/documentHighlight.
    -- Knobs (defaults shown):
    words = {
      enabled = true,
      debounce = 200,            -- ms before highlights update
      notify_jump = false,       -- toast on each jump
      notify_end = true,         -- toast when wrapping past the last ref
      foldopen = true,           -- open folds when jumping into them
      jumplist = true,           -- push a jumplist entry before jumping (so <C-o> returns)
      modes = { "n", "i", "c" }, -- highlight references in these modes
    },

    -- [3] indent: indent guides + animated current-scope guide. Replaces
    -- blink.indent (disabled in indent.lua) — only one may draw guides at a time.
    -- Scope detection uses treesitter when available, else indentation.
    indent = {
      enabled = true,
      indent = {
        char = "▏", -- U+258F hairline; thinnest straight guide
        -- hl defaults to SnacksIndent (muted); leave as-is
      },
      scope = {
        enabled = true,
        char = "▏",
        underline = false, -- no underline on the scope's first line
        hl = "Comment",    -- active scope slightly brighter than the dim guides
      },
      -- The bit you want to SEE: the scope guide animates toward the block your
      -- cursor enters. On by default for Neovim >= 0.10.
      animate = {
        enabled = true,
        style = "up_down",   -- grows up/down from the cursor (most visible)
        easing = "outCubic", -- smooth deceleration (default is "linear")
        duration = {
          step = 50,         -- ms per animation step
          total = 500,       -- cap the whole animation at 500ms
        },
      },
    },

    -- [4] bufdelete: intentionally unused. It keeps windows/splits open after
    -- deleting a buffer, which conflicts with native <C-w>c muscle memory.
    -- Use native window close (:q / :close / <C-w>c) and explicit :bdelete.

    -- [5] quickfile: render a file's first screen BEFORE the full plugin stack
    -- finishes loading, so opening files feels instant. Pairs with bigfile.
    -- needs_setup, so enabled must be set. `exclude` lists treesitter langs to
    -- skip the early render for (latex's parser is slow/heavy by default).
    quickfile = {
      enabled = true,
      exclude = { "latex" },
    },

    -- [6] gitbrowse: open the current repo/file/selection/commit in the system
    -- browser (GitHub/GitLab/etc). Wired to <leader>gb in keymap.lua. Uses the
    -- default fallback chain: commit under cursor -> file line/range -> branch
    -- -> repo, depending on what information is available.
    gitbrowse = {
      enabled = true,
    },

    -- [7] rename: a pure helper module (no setup/opts/enabled needed) for FILE
    -- renames, not symbol renames. Snacks.rename.rename_file() performs a file
    -- move and sends LSP workspace/willRenameFiles + didRenameFiles so imports
    -- can update. Oil integration lives in oil.lua; Snacks explorer/picker uses
    -- the same helper internally for its explorer_rename action.

    -- [8] scroll: smooth scrolling for normal/mouse scrolls while respecting
    -- scrolloff. No keymaps needed; it animates native scrolling commands.
    -- Defaults were a little floaty; keep it smooth but faster.
    scroll = {
      enabled = true,
      animate = {
        duration = { step = 8, total = 120 },
        easing = "linear",
      },
      animate_repeat = {
        delay = 100,
        duration = { step = 4, total = 35 },
        easing = "linear",
      },
    },

    -- [9] dashboard: "Ledger" start screen — modular two-pane layout from the
    -- design handoff (pure typography, dot leaders, toggleable right-column
    -- modules). ALL layout/modules/keys live in lua/config/dashboard.lua;
    -- `sections` is a function so that file only loads when the dashboard
    -- actually opens. `width` here is the MAX pane width; sections() shrinks it
    -- responsively per window (writing dash.opts.width) so the two 52-col panes
    -- (+6 gap ≈ the design's 110-col block) scale down instead of overflowing.
    -- snacks passes the dashboard instance to the section function — forward it.
    dashboard = {
      enabled = true,
      width = 52,
      pane_gap = 6,
      sections = function(dash)
        return require("config.dashboard").sections(dash)
      end,
    },

    -- [10] picker: enable only the picker core so `gs` can use Snacks' tree
    -- shaped LSP symbol view. Telescope remains the default for files/grep.
    -- Keep `vim.ui.select` untouched for now; QuickBind has its own selection
    -- flow and we do not want a global UI swap as a side effect of symbol nav.
    picker = {
      enabled = true,
      ui_select = false,
      sources = {
        lsp_symbols = {
          -- Show the nested outline instead of a flat fuzzy list, and keep the
          -- containing class/object/module visible while filtering so matches
          -- still have code-structure context.
          tree = true,
          keep_parents = true,

          -- Snacks' built-in `lsp_symbols` source uses a curated SymbolKind
          -- allow-list. That is tidy, but it hid symbols that Telescope showed
          -- during testing: TS/Lua language servers can report "function-like"
          -- code as Variable/Constant/Object depending on syntax. In TypeScript,
          -- arrow functions like `const foo = () => {}` commonly come back as
          -- SymbolKind.Variable, not SymbolKind.Function. `default = true` means
          -- "show every SymbolKind the LSP returns" for normal filetypes.
          -- `lua = true` is explicit because Snacks ships a Lua-specific filter,
          -- and without overriding it Lua would keep the curated list.
          filter = {
            default = true,
            lua = true,
          },
        },
      },
    },
  },
}
