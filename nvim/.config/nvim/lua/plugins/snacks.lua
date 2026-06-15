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
--   picker     -> Snacks now owns files/grep/LSP picker flows.
--   notifier, input, explorer -> larger scope,
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
    bigfile      = {
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
    words        = {
      enabled = true,
      -- Single debounce for ALL modes. CursorMovedI fires every keystroke, so a
      -- larger value is what keeps insert mode from re-highlighting per char: the
      -- timer resets on each keystroke and only runs document_highlight() once you
      -- PAUSE for this long. Tradeoff: it also delays the normal-mode highlight by
      -- the same amount, so don't crank it too high. Lower if normal mode feels laggy.
      debounce = 500,            -- ms before highlights update (was 200)
      notify_jump = false,       -- toast on each jump
      notify_end = true,         -- toast when wrapping past the last ref
      foldopen = true,           -- open folds when jumping into them
      jumplist = true,           -- push a jumplist entry before jumping (so <C-o> returns)
      modes = { "n", "v", "i" }, -- insert is back, but only fires after the debounce pause
    },

    -- [3] indent: indent guides + animated current-scope guide. Replaces
    -- blink.indent (disabled in indent.lua) — only one may draw guides at a time.
    -- Scope detection uses treesitter when available, else indentation.
    indent       = {
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

    -- NOTE: Snacks.scope is a separate navigation module from indent.scope.
    -- Enable it later if you want Snacks.scope.jump() for top/bottom/parent
    -- indentation-scope jumps. Its defaults use [i / ]i, which currently belong
    -- to Treesitter conditional motions in textobjects.lua, so choose new keys
    -- or disable/remap those defaults before turning it on.

    -- [4] bufdelete: intentionally unused. It keeps windows/splits open after
    -- deleting a buffer, which conflicts with native <C-w>c muscle memory.
    -- Use native window close (:q / :close / <C-w>c) and explicit :bdelete.

    -- [5] quickfile: render a file's first screen BEFORE the full plugin stack
    -- finishes loading, so opening files feels instant. Pairs with bigfile.
    -- needs_setup, so enabled must be set. `exclude` lists treesitter langs to
    -- skip the early render for (latex's parser is slow/heavy by default).
    quickfile    = {
      enabled = true,
      exclude = { "latex" },
    },

    -- [6] gitbrowse: open the current repo/file/selection/commit in the system
    -- browser (GitHub/GitLab/etc). Wired to <leader>gb in keymap.lua. Uses the
    -- default fallback chain: commit under cursor -> file line/range -> branch
    -- -> repo, depending on what information is available.
    gitbrowse    = {
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
    scroll       = {
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

    -- [9] statuscolumn: replace the default gutter with Snacks' composed
    -- status column. It keeps native number/relativenumber behavior, pulls
    -- regular signs/diagnostics/marks to the left, and Git/fold indicators to
    -- the right. Fold icons only appear in windows where foldcolumn is nonzero.
    -- See :help 'statuscolumn' and snacks.nvim-statuscolumn.
    statuscolumn = {
      enabled = true,
      left = { "mark", "sign" },
      right = { "fold", "git" },
      folds = {
        open = false,
        git_hl = false,
      },
      git = {
        patterns = { "GitSign", "MiniDiffSign" },
      },
      refresh = 50,
    },

    -- [10] dashboard: "Ledger" start screen — modular two-pane layout from the
    -- design handoff (pure typography, dot leaders, toggleable right-column
    -- modules). ALL layout/modules/keys live in lua/config/dashboard.lua;
    -- `sections` is a function so that file only loads when the dashboard
    -- actually opens. `width` here is the MAX pane width; sections() shrinks it
    -- responsively per window (writing dash.opts.width) so the two 52-col panes
    -- (+6 gap ≈ the design's 110-col block) scale down instead of overflowing.
    -- snacks passes the dashboard instance to the section function — forward it.
    dashboard    = {
      enabled = true,
      width = 52,
      pane_gap = 6,
      sections = function(dash)
        return require("config.dashboard").sections(dash)
      end,
    },

    -- [11] picker: Snacks now owns files/grep/LSP picker flows plus vim.ui.select
    -- so plugins using the generic selection API get the same picker UI.
    picker       = {
      enabled = true,
      ui_select = true,
      actions = {
        flash = function(picker)
          require("flash").jump({
            pattern = "^",
            label = { after = { 0, 0 } },
            search = {
              mode = "search",
              exclude = {
                function(win)
                  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                end,
              },
            },
            action = function(match)
              local idx = picker.list:row2idx(match.pos[1])
              picker.list:_move(idx, true, true)
            end,
          })
        end,
        trouble_open = function(picker)
          require("trouble.sources.snacks").open(picker, { type = "smart" })
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-s>"] = { "confirm", mode = { "i", "n" } },
            -- Flash-jump to a visible picker row.
            ["<a-s>"] = { "flash", mode = { "n", "i" } },

            -- Only normal mode: don't steal literal "s" while typing in picker input.
            ["s"] = { "flash", mode = "n" },

            -- Send the current Snacks picker results to Trouble.
            ["<C-t>"] = { "trouble_open", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<C-s>"] = "confirm",
            ["<C-t>"] = "trouble_open",
            -- Useful if focus is in the result list instead of input.
            ["s"] = "flash",
          },
        },
      },
      sources = {
        lsp_symbols = {
          -- Show the nested outline instead of a flat fuzzy list, and keep the
          -- containing class/object/module visible while filtering so matches
          -- still have code-structure context.
          tree = true,
          keep_parents = true,

          -- Snacks' built-in `lsp_symbols` source uses a curated SymbolKind
          -- allow-list. That is tidy, but it hid symbols that previous picker
          -- testing showed: TS/Lua language servers can report "function-like"
          -- code as Variable/Constant/Object depending on syntax. In TypeScript,
          -- arrow functions like `const foo = () => {}` commonly come back as
          -- SymbolKind.Variable, not SymbolKind.Function. `default = true` means
          -- "show every SymbolKind the LSP returns" for normal filetypes.
          -- `lua = true` is explicit because Snacks ships a Lua-specific filter,
          -- and without overriding it Lua would keep the curated list.
          filter = {
            default = true,
            -- lua = true,
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader><space>",
      function() Snacks.picker.smart() end,
      desc = "Smart Find Files",
      mode = { "n", "x" }
    },
    {
      "<leader>,",
      function() Snacks.picker.buffers() end,
      desc = "Buffers",
      mode = { "n", "x" }
    },
    {
      "<leader>/",
      function() Snacks.picker.grep() end,
      desc = "Grep",
      mode = { "n" }
    },
    {
      "<leader>/",
      function()
        Snacks.picker.grep_word(
          {
            args = {} -- disable '-w' rg flag, want exact match
          }
        )
      end,
      desc = "Grep Selection",
      mode = "x",
    },
    { "<leader>:",  function() Snacks.picker.command_history() end,                         desc = "Command History" },
    { "<leader>n",  function() Snacks.picker.notifications() end,                           desc = "Notification History" },
    { "<leader>e",  function() Snacks.explorer() end,                                       desc = "File Explorer" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>ff", function() Snacks.picker.files() end,                                   desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
    { "<leader>fp", function() Snacks.picker.projects() end,                                desc = "Projects" },
    { "<leader>fr", function() Snacks.picker.recent() end,                                  desc = "Recent" },
    -- git
    { "<leader>gb", function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
    { "<leader>gl", function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
    { "<leader>gs", function() Snacks.picker.git_status() end,                              desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
    { "<leader>gd", function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
    -- gh
    { "<leader>gi", function() Snacks.picker.gh_issue() end,                                desc = "GitHub Issues (open)" },
    { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end,               desc = "GitHub Issues (all)" },
    { "<leader>gp", function() Snacks.picker.gh_pr() end,                                   desc = "GitHub Pull Requests (open)" },
    { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end,                  desc = "GitHub Pull Requests (all)" },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end,                            desc = "Grep Open Buffers" },
    -- search
    { '<leader>s"', function() Snacks.picker.registers() end,                               desc = "Registers" },
    { '<leader>s/', function() Snacks.picker.search_history() end,                          desc = "Search History" },
    { "<leader>sa", function() Snacks.picker.autocmds() end,                                desc = "Autocmds" },
    { "<leader>sC", function() Snacks.picker.commands() end,                                desc = "Commands" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end,                             desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end,                      desc = "Buffer Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end,                                    desc = "Help Pages" },
    { "<leader>sH", function() Snacks.picker.highlights() end,                              desc = "Highlights" },
    { "<leader>si", function() Snacks.picker.icons() end,                                   desc = "Icons" },
    { "<leader>sj", function() Snacks.picker.jumps() end,                                   desc = "Jumps" },
    { "<leader>sk", function() Snacks.picker.keymaps() end,                                 desc = "Keymaps" },
    { "<leader>sl", function() Snacks.picker.loclist() end,                                 desc = "Location List" },
    { "<leader>sm", function() Snacks.picker.marks() end,                                   desc = "Marks" },
    { "<leader>sM", function() Snacks.picker.man() end,                                     desc = "Man Pages" },
    { "<leader>sp", function() Snacks.picker.lazy() end,                                    desc = "Search for Plugin Spec" },
    { "<leader>sq", function() Snacks.picker.qflist() end,                                  desc = "Quickfix List" },
    { "<leader>sR", function() Snacks.picker.resume() end,                                  desc = "Resume" },
    { "<leader>su", function() Snacks.picker.undo() end,                                    desc = "Undo History" },
    { "<leader>uC", function() Snacks.picker.colorschemes() end,                            desc = "Colorschemes" },
    -- LSP
    { "gd",         function() Snacks.picker.lsp_definitions() end,                         desc = "Goto Definition" },
    { "gD",         function() Snacks.picker.lsp_declarations() end,                        desc = "Goto Declaration" },
    { "grr",        function() Snacks.picker.lsp_references() end,                          nowait = true,                       desc = "References" },
    { "gI",         function() Snacks.picker.lsp_implementations() end,                     desc = "Goto Implementation" },
    { "gy",         function() Snacks.picker.lsp_type_definitions() end,                    desc = "Goto T[y]pe Definition" },
    { "gai",        function() Snacks.picker.lsp_incoming_calls() end,                      desc = "C[a]lls Incoming" },
    { "gao",        function() Snacks.picker.lsp_outgoing_calls() end,                      desc = "C[a]lls Outgoing" },
    { "gs",         function() Snacks.picker.lsp_symbols() end,                             desc = "LSP Symbols" },
    { "gS",         function() Snacks.picker.lsp_workspace_symbols() end,                   desc = "LSP Workspace Symbols" },

  }
}
