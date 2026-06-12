local group = vim.api.nvim_create_augroup("UserAutocmds", { clear = true })

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

-- When the last real buffer is deleted (<C-w>c, :bd, ...), nvim lands on an
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
        Snacks.dashboard.open({
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
  end,
})
