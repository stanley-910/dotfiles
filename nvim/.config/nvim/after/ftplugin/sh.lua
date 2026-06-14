vim.opt_local.expandtab = true
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = -1 -- follow shiftwidth for insert-mode <Tab>/<BS>
vim.opt_local.colorcolumn = "101"

-- remove 'o'/<CR> insert comment behaviour
vim.opt.formatoptions:remove({ "o", "r" })

local compiler = vim.fn.executable("shellcheck") == 1 and "shellcheck" or "bash"

-- Bad Vim name: this does not compile shell.
-- It sets buffer-local makeprg/errorformat so :make fills quickfix correctly.
vim.cmd.compiler(compiler)

local function check_shell_script()
  if vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("Save the script before checking", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified then
    vim.cmd.write()
  end

  vim.cmd("silent make %:S")

  if #vim.fn.getqflist() == 0 then
    vim.notify(compiler .. ": no issues", vim.log.levels.INFO)
  else
    vim.cmd.cwindow()
  end
end

vim.keymap.set("n", "<leader>m", check_shell_script, {
  buffer = true,
  desc = "Check shell script",
})

vim.keymap.set("n", "<leader>f", function()
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("conform.nvim is not available", vim.log.levels.WARN)
    return
  end

  conform.format({
    bufnr = 0,
    async = true,
    lsp_format = "fallback",
  })
end, {
  buffer = true,
  desc = "Format shell script",
})
