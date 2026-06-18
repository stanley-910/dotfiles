return {
  'saghen/blink.cmp',
  -- optional: provides snippets for the snippet source
  dependencies = { 'rafamadriz/friendly-snippets' },

  -- use a release tag to download pre-built binaries
  version = '1.*',

  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap.
    -- Let insert-mode <C-k> fall through to config/keymap.lua instead of
    -- Blink's default signature-help toggle. Use <D-p> for Cmd-p on UIs/
    -- terminals that forward the macOS Command key to Neovim.
    keymap = {
      preset = 'default',
      ['<C-j>'] = { 'select_next', 'fallback_to_mappings' },
      ['<C-k>'] = { 'select_prev', 'fallback_to_mappings' },
      ['<C-n>'] = false,
      ['<C-p>'] = false,
      -- Insert/select <Tab> orchestration lives in lua/plugins/tabout.lua.
      ['<Tab>'] = false,
      ['<S-Tab>'] = false,
      ['<C-s>'] = { 'select_and_accept', 'fallback' },
      ['<C-q>'] = { 'show_signature', 'hide_signature', 'fallback' },
      ['<C-e>'] = { 'fallback_to_mappings' },
      ['<M-e>'] = { 'hide', 'fallback' },
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono'
    },
    signature = { enabled = true },

    -- In insert mode, selecting an item should only focus it. <C-s> and the
    -- mini.keymap <Tab> orchestration explicitly accept the focused item.
    completion = {
      list = {
        selection = {
          auto_insert = false,
        },
      },
      menu = {
        -- Add a right-hand column spelling out the item KIND (Function, Module,
        -- Constant, Snippet, …) next to the kind icon, so ambiguous icons (e.g.
        -- Function/Method and Class/Struct/Interface share a glyph) are readable.
        -- Default columns are { {'kind_icon'}, {'label','label_description'} }.
        draw = {
          columns = {
            { "kind_icon" },
            { "label", "label_description", gap = 1 },
            { "kind" },
          },
        },
      },
      documentation = {
        auto_show = true,
        -- Wait 500ms on an item before popping docs, so the window doesn't
        -- flicker in/out while arrowing quickly through the list.
        auto_show_delay_ms = 500,
        -- Match native LSP hover's frame (config/lsp.lua uses border="rounded").
        window = { border = "rounded" },

        -- NOTE: this docs window won't fully match native `K` hover, on purpose.
        -- blink hand-rolls its treesitter highlighting (lib/window/docs.lua) and
        -- only honors per-node `conceal`, NOT `conceal_lines`. Modern markdown
        -- hides code-fence lines (```lang) via `conceal_lines`
        -- (runtime/queries/markdown/highlights.scm), so blink shows the ``` and
        -- language as literal text where native hover (Neovim's real
        -- vim.treesitter highlighter) hides them.
        --
        -- A custom `draw` that builds the buffer with blink off and then attaches
        -- the real highlighter (vim.treesitter.start(buf,"markdown")) DOES fix
        -- it, but it reaches into blink internals (default_implementation, the
        -- reused docs buffer) and is too fragile to keep. Revisit if blink gains
        -- native conceal_lines support, or re-add the draw if the look matters
        -- more than the fragility.
      },
    },

    -- Command-line completion should open while typing commands. <C-j>/<C-k>
    -- only move focus. <C-n>/<C-p> are disabled here so Neovim's native
    -- command-line history cycling can handle them; see :help c_CTRL-N and
    -- :help c_CTRL-P.
    cmdline = {
      keymap = {
        preset = 'cmdline',
        -- ['<Tab>'] = { insert_focused_cmdline_item, 'fallback' },
        -- ['<S-Tab>'] = { 'select_prev', 'show', 'fallback' },
        ['<Tab>'] = { 'select_and_accept', 'fallback' },
        ['<C-j>'] = { 'select_next', 'fallback_to_mappings' },
        ['<C-k>'] = { 'select_prev', 'fallback_to_mappings' },
        ['<C-n>'] = false,
        ['<C-p>'] = false,
        ['<C-s>'] = { 'select_and_accept', 'fallback' },
        ['<C-y>'] = false,
      },
      completion = {
        list = {
          selection = {
            auto_insert = false,
          },
        },
        menu = {
          auto_show = function()
            return vim.fn.getcmdtype() == ':'
          end,
        },
      },
    },

    sources = {
      -- LazyDev adds high-priority completions for Lua `require(...)` and
      -- `---@module` annotations while editing this Neovim config.
      default = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer' },
      providers = {
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          score_offset = 100,
        },
      },
    },

    -- Route snippet expansion through LuaSnip so Lua-authored snippets under
    -- lua/snippets/<filetype>.lua can use choice/dynamic/function nodes.
    snippets = { preset = "luasnip" },

    -- Use Lua implementation to avoid needing Rust nightly and pre-built binaries
    -- This prevents the "No fuzzy matching library found" warning on startup
    fuzzy = { implementation = "lua" }
  },
  opts_extend = { "sources.default" }
}
