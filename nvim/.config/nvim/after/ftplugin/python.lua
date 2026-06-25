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
