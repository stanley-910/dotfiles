local group = vim.api.nvim_create_augroup("UserAutocmds", { clear = true }) -- don't duplicate autocommands on reload

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Highlight yanked text like visual selection",
  callback = function()
    vim.hl.on_yank({
      higroup = "Visual",
      timeout = 150,
    })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  desc = "Restore cursor position when reopening files",
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(event.buf)

    if mark[1] > 1 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("SolidDiagnosticUnderline", { clear = true }),
  callback = function()
    for _, g in ipairs({
      "Error",
      "Warn",
      "Info",
      "Hint",
      "Ok",
    }) do
      local name = "DiagnosticUnderline" .. g
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      -- Re-set with a fresh table (inferred as keyset.highlight) instead of
      -- round-tripping the get_hl_info shape. Preserve the underline color (sp),
      -- swap undercurl -> solid underline.
      vim.api.nvim_set_hl(0, name, {
        fg = hl.fg,
        bg = hl.bg,
        sp = hl.sp,
        underdotted = true,
      })
    end
  end,
})

-- When the last real buffer is deleted (:bd, quickbind buffer.delete, ...), nvim lands on an
-- empty [No Name] scratch window. Show the dashboard there instead, reusing
-- that window/buffer the same way the startup path does. Scheduled because
-- BufDelete fires BEFORE the buffer list updates.
vim.api.nvim_create_autocmd("BufDelete", {
  group = group,
  desc = "Reopen the dashboard when the last buffer is deleted",
  callback = function()
    vim.schedule(function()
      -- only act when we actually fell back to an empty, unnamed, unmodified
      -- normal buffer (not oil/terminal/help, not the dashboard itself)
      if
          vim.bo.filetype ~= ""
          or vim.bo.buftype ~= ""
          or vim.api.nvim_buf_get_name(0) ~= ""
          or vim.bo.modified
      then
        return
      end
      local listed = vim.tbl_filter(function(b)
        return b.name ~= "" or b.changed == 1
      end, vim.fn.getbufinfo({ buflisted = 1 }))
      if #listed == 0 and Snacks then
        Snacks.dashboard.open({ -- TODO undefined global snacks
          buf = vim.api.nvim_get_current_buf(),
          win = vim.api.nvim_get_current_win(),
        })
      end
    end)
  end,
})

-- LSP reference highlights (shown by snacks `words` via vim.lsp.buf.document_highlight).
-- Kanagawa gives LspReferenceWrite a background AND an underline, while Text/Read
-- get the same background with no underline. Link Write -> Text so write refs keep
-- the subtle background but drop the underline, staying in sync with Text's color.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LspReferenceNoUnderline", { clear = true }),
  callback = function()
    vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "LspReferenceText" })
  end
})


-- :set ft? for help-pages
--  filetype=help
--  quitting help file doesn't close the buffer, prob cuz still open?, yeah :q isnt enough you need to close the buffer
--  buffer nr is passed through event args
--
-- • id: (`number`) Autocommand id
-- • event: (`vim.api.keyset.events`) Name of the triggered
--   event |autocmd-events|
-- • group: (`number?`) Group id, if any
-- • file: (`string`) <afile> (not expanded to a full path)
-- • match: (`string`) <amatch> (expanded to a full path) -- this is filepath
-- • buf: (`number`) <abuf>
-- • data: (`any`) Arbitrary data passed from
-- :h FileType state: <amatch> is the new value of 'filetype'.



vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "help",
  desc = "Show help pages as right splits with minimal gutter",
  callback = function()
    -- Leave help buffers unlisted unless you really want them in buffer pickers.
    -- vim.bo.buflisted = true

    -- get rid of empty gutter space
    -- vim.opt_local.signcolumn = "no"
    -- vim.opt_local.foldcolumn = "1"
    -- vim.opt_local.statuscolumn = ""

    vim.cmd.wincmd("L")
  end,
})
