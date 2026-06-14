return {
  "j-hui/fidget.nvim",
  -- Upstream recommends release tags because main can occasionally break.
  version = "*",
  -- Load at startup so the LSP $/progress handler is ready before servers emit work-done progress.
  opts = {
    progress = {
      -- Keep completion/indexing chatter out of the way while typing.
      suppress_on_insert = true,
      display = {
        render_limit = 8,
        done_ttl = 2,
        done_icon = "✓",
      },
    },
    notification = {
      -- Do not replace vim.notify globally; this keeps notification backend choice explicit.
      override_vim_notify = false,
    },
  },
}
