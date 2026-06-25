local first_progress_token_by_client = {}

local function default_progress_handler(err, result, ctx, config)
  return vim.lsp.handlers["$/progress"](err, result, ctx, config)
end

---@type vim.lsp.Config
return {
  cmd = { "basedpyright-langserver", "--stdio" },

  -- :help vim.lsp.handlers
  -- basedpyright sends LSP `$/progress` work-done notifications for ordinary
  -- edit analysis, not just initial setup. Fidget listens to Neovim's
  -- LspProgress event, which is emitted by the default `$/progress` handler;
  -- if every basedpyright progress token reaches that handler, Fidget renders a
  -- repeated bottom-right "Completed basedpyright ✓" toast after edits.
  --
  -- Let only the first progress token for each basedpyright client reach the
  -- default handler. That preserves the useful first setup/ready notification
  -- when a Python workspace starts, while later edit-analysis tokens are
  -- dropped before Fidget can see them. This stays local to basedpyright rather
  -- than teaching Fidget special cases about one language server.
  handlers = {
    ["$/progress"] = function(err, result, ctx, config)
      local token = result and result.token
      if token == nil then
        return default_progress_handler(err, result, ctx, config)
      end

      local client_id = ctx and ctx.client_id or 0
      local first_token = first_progress_token_by_client[client_id]
      if first_token == nil then
        first_token = token
        first_progress_token_by_client[client_id] = token
      end

      if token == first_token then
        return default_progress_handler(err, result, ctx, config)
      end

      -- Later basedpyright progress tokens are intentionally swallowed. The
      -- language server still runs analysis and publishes diagnostics; this only
      -- filters the progress UI path.
    end,
  },

  on_exit = function(_, _, client_id)
    first_progress_token_by_client[client_id] = nil
  end,
}
