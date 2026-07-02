-- Visual-mode K runs 'keywordprg' on the selection (:help v_K). Python's builtin
-- ftplugin sets keywordprg=`python3 -m pydoc`, so selecting text and pressing K
-- piped the whole selection into pydoc ("No Python documentation found for…").
-- Shadow it buffer-locally for Python so visual K does nothing here. Normal-mode
-- K (LSP hover, config/lsp.lua) is unaffected, as is visual K in other filetypes.
vim.keymap.set("x", "K", "<Nop>", {
  buffer = true,
  silent = true,
  desc = "Disable pydoc lookup on selection",
})
-- opening parens tab should only be '4' not '8'
vim.g.python_indent = vim.tbl_extend("force", vim.g.python_indent or {}, {
  open_paren = "shiftwidth()",
})

-- Blank-line-aware o/O. Python's indentexpr (python#GetIndent) returns -1 for
-- ordinary statements, which per :help 'indentexpr' means "keep current indent —
-- use 'autoindent'". 'autoindent' copies the *current* line's indent, but a blank
-- line reached via { } / paragraph motions has no whitespace, so native o/O drop
-- the cursor to the gutter. On blank lines we open at the surrounding block's
-- indent instead.
--
-- This is imperative (not an expr map) on purpose: native o/O already indent
-- correctly after a `:` or a return/pass (their indentexpr returns a concrete
-- value), so *appending* our own indent would double-count. Instead we let
-- non-blank lines fall through to native o/O untouched, and on blank lines we
-- insert a line pre-filled to the absolute target indent.
--
-- blank_aware_open is a closure factory: it bakes in `key` ("o"/"O") and returns
-- the handler that runs on keypress.
local function blank_aware_open(key)
  return function()
    local lnum = vim.fn.line(".")

    -- non-blank line (^%s*$ also catches whitespace-only) -> native o/O, so
    -- dot-repeat, counts, and the script's own indent logic are all preserved.
    if not vim.api.nvim_get_current_line():match("^%s*$") then
      local prefix = vim.v.count > 0 and tostring(vim.v.count) or ""
      vim.api.nvim_feedkeys(prefix .. key, "n", false) -- "n": no remap, no recursion
      return
    end

    -- blank line -> open at the indent of the line we're opening *toward*: O opens
    -- above the gap so it mirrors the line above (prevnonblank); o opens below so
    -- it mirrors the line below (nextnonblank). Each falls back to the other end
    -- if its side is empty (gap at top/bottom of file).
    local refnum
    if key == "o" then
      refnum = vim.fn.nextnonblank(lnum)
      if refnum == 0 then refnum = vim.fn.prevnonblank(lnum) end
    else
      refnum = vim.fn.prevnonblank(lnum)
      if refnum == 0 then refnum = vim.fn.nextnonblank(lnum) end
    end

    local ind = refnum == 0 and 0 or vim.fn.indent(refnum)
    -- The `:`-opens-a-block rule only applies when the reference line is *above*
    -- the new line (we'd be its block's first line). When mirroring a line below,
    -- we match its indent verbatim — it's a sibling, not a header we're entering.
    -- Strip a trailing comment first so `if x:  # note` / `def f():  # note` still
    -- read as headers. This is deliberately naive (a `#` inside a string can fool
    -- it); going fully syntax-aware would mean re-implementing the indent script.
    if refnum > 0 and refnum < lnum then
      local ref_code = vim.fn.getline(refnum):gsub("%s*#.*$", "")
      if ref_code:match(":%s*$") then
        ind = ind + vim.fn.shiftwidth() -- one level deeper after a `...:` header
      end
    end

    -- Insert the new line (after `lnum` for o, before it for O) pre-filled with
    -- the absolute indent, then drop into insert mode at its end.
    local at = key == "o" and lnum or lnum - 1 -- 0-based insertion index
    vim.api.nvim_buf_set_lines(0, at, at, false, { string.rep(" ", ind) })
    vim.api.nvim_win_set_cursor(0, { at + 1, 0 })
    vim.cmd("startinsert!")
  end
end

vim.keymap.set("n", "o", blank_aware_open("o"), { buffer = true, desc = "Open line below (blank-line indent aware)" })
vim.keymap.set("n", "O", blank_aware_open("O"), { buffer = true, desc = "Open line above (blank-line indent aware)" })

