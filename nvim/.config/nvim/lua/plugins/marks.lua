-- marks.nvim — view / add / delete / toggle / cycle vim marks in the sign
-- column, plus a separate "bookmarks" feature (groups 0-9) for persistent,
-- optionally-annotated markers.
--
-- WHY THIS EXISTS (the gutter story):
-- Snacks' statuscolumn "mark" component only renders a-zA-Z *letter* marks — it
-- filters with `mark.mark:match("[a-zA-Z]")`, so builtin marks ('<, '>, '', '^)
-- and any richer mark UX never reached the gutter. We hand ALL mark rendering to
-- marks.nvim and tell Snacks to stop drawing its own "mark" layer
-- (lua/plugins/snacks.lua: statuscolumn.right = { "sign", "fold" }).
-- marks.nvim places real vim signs via sign_place(); on Neovim >= 0.10 those
-- legacy signs are returned by nvim_buf_get_extmarks(type="sign"), which is
-- exactly what Snacks' "sign" component reads — so every mark type now shows in
-- one uniform style.
--
-- SEARCH / PICKER (the "keep it searchable" story):
--   * a-z / A-Z / builtin marks are real vim marks, so Snacks.picker.marks
--     (<leader>sm in snacks.lua) keeps listing them with zero extra wiring.
--   * marks.nvim *bookmarks* are extmark-based, NOT vim marks, so they are
--     routed into Snacks via its quickfix picker (<leader>mb below) using the
--     plugin's own :BookmarksQFListAll command.
--
-- PRIORITY: Snacks' statuscolumn shows a single sign per side, highest-priority
-- wins, so bookmark marks rank above ordinary marks and DAP signs. Diagnostic
-- signs are disabled in config/lsp.lua, so diagnostics do not compete for this
-- gutter slot.
--
-- DEFAULT MAPPINGS (from default_mappings = true; native `m`/`dm` are overlaid):
--   mx          set mark x            dmx         delete mark x
--   m,          set next mark         dm-         delete marks on line
--   m;          toggle next mark      dm<space>   delete marks in buffer
--   m]  m[      next / prev mark      m:          preview a mark
--   m0..m9      set bookmark group    dm0..dm9    delete bookmark group
--   m}  m{      next / prev bookmark  dm=         delete bookmark under cursor
--
-- See: https://github.com/chentoast/marks.nvim   (:help marks-nvim)
return {
  "chentoast/marks.nvim",
  -- Load shortly after startup so the m/dm maps and sign tracking are live for
  -- the first buffer; the <leader>m keys below are extra lazy-load triggers.
  event = "VeryLazy",
  keys = {
    -- All vim marks (a-z, A-Z, builtin) through the Snacks picker. Mirrors
    -- <leader>sm so the marks UI is also discoverable under the <leader>m group.
    { "<leader>mm", function() Snacks.picker.marks() end,            desc = "Marks (picker)" },

    -- marks.nvim bookmarks aren't vim marks, so surface them via the plugin's
    -- quickfix list, then hand THAT list to the Snacks picker. We call the
    -- bookmark API directly instead of the :BookmarksQFListAll command, because
    -- that command is defined as `...all_to_list('quickfixlist') | copen` — the
    -- `| copen` would also pop the native quickfix window. all_to_list() is a
    -- plain setqflist (no window), so only the Snacks picker opens.
    -- (bookmark_state is the same public field the plugin's own commands use.)
    {
      "<leader>mb",
      function()
        require("marks").bookmark_state:all_to_list("quickfixlist")
        Snacks.picker.qflist()
      end,
      desc = "Bookmarks (picker)",
    },

    -- Same bookmarks, but in the Trouble right panel (see lua/plugins/trouble.lua
    -- `bookmarks` mode). Populate the qf list first, then open the Trouble mode
    -- that renders it.
    {
      "<leader>mt",
      function()
        require("marks").bookmark_state:all_to_list("quickfixlist")
        vim.cmd("Trouble bookmarks open")
      end,
      desc = "Bookmarks (Trouble)",
    },

    -- Cycle bookmarks of the group under the cursor ("current group"), across
    -- buffers. These OVERRIDE the native ]' / [' motions (next/prev line with a
    -- lowercase mark) — that native behavior is redundant with m] / m[ (next/
    -- prev mark), and these keys fit the existing ]b / ]d bracket convention.
    -- The default m} / m{ bindings for the same action are disabled in opts.
    { "]'",         function() require("marks").next_bookmark() end, desc = "Next bookmark (group)" },
    { "['",         function() require("marks").prev_bookmark() end, desc = "Prev bookmark (group)" },
  },
  opts = {
    default_mappings = true,
    signs = true,

    -- Drop the default m} / m{ (next/prev bookmark) — that action now lives on
    -- ]' / [' (see keys above), keeping one clear binding per action.
    mappings = {
      next_bookmark = false,
      prev_bookmark = false,
    },

    -- Builtin marks to also track in the gutter. Conservative set:
    --   '<  '>  last visual-selection bounds (stable, handy)
    --   ''      position before the last jump
    --   '^      last insert position
    -- '.' (last change) is intentionally omitted — it moves on every edit and
    -- turns the gutter into noise. Add "." here if you decide you want it.
    builtin_marks = { "<", ">", "'", "^" },

    -- Wrap past the first/last mark when navigating with m] / m[.
    cyclic = true,

    -- Don't rewrite the shada file when deleting uppercase (global) marks.
    force_write_shada = false,

    -- How often (ms) mark signs are recomputed after edits.
    refresh_interval = 150,

    -- Sign priority per mark class. The right Snacks sign slot shows one sign
    -- per line; bookmarks rank highest so they win over ordinary marks.
    sign_priority = { lower = 20, upper = 20, builtin = 18, bookmark = 25 },

    -- Don't track marks in transient / UI buffers.
    excluded_filetypes = {
      "snacks_dashboard",
      "snacks_picker_list",
      "snacks_picker_input",
      "oil",
      "trouble",
      "help",
      "qf",
      "lazy",
      "mason",
    },
    excluded_buftypes = {
      "acwrite",
      "help",
      "nofile",
      "nowrite",
      "prompt",
      "quickfix",
      "terminal",
    },

    -- Bookmark group 0 gets a distinct flag glyph; groups 1..9 keep the default
    -- "!@#$%^&*(" signs. virt_text/annotate left at defaults (off).
    bookmark_0 = {
      sign = "⚑",
    },
  },

  -- DIM THE MARK LINE NUMBER. marks.nvim defines every sign with
  -- numhl = "MarkSignNumHL", default-linked to CursorLineNr (bold orange in
  -- kanagawa). Neovim uses a sign's numhl as the default highlight for the
  -- statuscolumn number, so the LINE NUMBER of any marked line lights up in the
  -- cursor-line accent — loud, and near-constant for auto-set builtin marks
  -- ('' last jump, '^ last insert). Re-link the group to a muted highlight.
  --
  -- Must re-apply on every ColorScheme: `:colorscheme` runs `hi clear`, and
  -- marks.nvim's `hi default link` only ran once when the plugin was sourced —
  -- so after a theme switch (the dashboard `t` picker swaps schemes live) the
  -- group would otherwise fall back to undefined. See :help nvim_set_hl and
  -- :help ColorScheme. Swap "Comment" for "LineNr" to match normal line numbers
  -- exactly (incl. gutter bg), or "NonText" for the dimmest look.
  config = function(_, opts)
    require("marks").setup(opts)

    local excluded_filetypes = {}
    for _, ft in ipairs(opts.excluded_filetypes or {}) do
      excluded_filetypes[ft] = true
    end

    local excluded_buftypes = {}
    for _, bt in ipairs(opts.excluded_buftypes or {}) do
      excluded_buftypes[bt] = true
    end

    local function clear_excluded_buffer_marks(buf)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
      if not excluded_buftypes[buftype] and not excluded_filetypes[filetype] then
        return
      end

      vim.fn.sign_unplace("MarkSigns", { buffer = buf })
      local ok, marks = pcall(require, "marks")
      if ok and marks.mark_state then
        marks.mark_state.buffers[buf] = nil
      end
    end

    local transient_marks_group = vim.api.nvim_create_augroup("UserMarksTransientBuffers", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "TermOpen", "WinEnter" }, {
      group = transient_marks_group,
      desc = "Hide marks.nvim signs in transient buffers",
      callback = function(event)
        clear_excluded_buffer_marks(event.buf)
      end,
    })

    local function dim_mark_num()
      vim.api.nvim_set_hl(0, "MarkSignNumHL", { link = "Comment" })
    end
    vim.api.nvim_create_autocmd("ColorScheme", { callback = dim_mark_num })
    dim_mark_num()
  end,
}
