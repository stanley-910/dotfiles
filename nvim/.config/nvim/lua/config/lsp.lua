local lsp_group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })

vim.diagnostic.config({
  -- No diagnostic signs in the gutter. NOTE: a table value here (even with an
  -- empty `text`) keeps the sign handler ENABLED, so commenting out the glyphs
  -- alone does not disable signs — `false` does. Severity still reads via the
  -- `underline` below and the K hover/float.
  signs = false,
  underline = true,
  -- true: refresh diagnostics live as you type (deliberate — preferred here).
  -- This is just Neovim re-placing signs/underline; it does NOT involve noice.
  -- The per-keystroke noice spam was its lsp.progress spinner, disabled in
  -- noice.lua — a separate mechanism from this option.
  update_in_insert = false,
  virtual_text = false,
  virtual_lines = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
  },
})

local function show_diagnostic_float(bufnr, scope)
  return vim.diagnostic.open_float({
    bufnr = bufnr,
    scope = scope or "cursor",
    source = true,
    border = "rounded",
    focus = false,
    focusable = true,
  })
end

local function show_hover()
  vim.lsp.buf.hover({
    border = "rounded",
    focus = false,
    focusable = true,
  })
end

local function is_focusable_floating_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end

  local config = vim.api.nvim_win_get_config(win)
  return config.relative ~= "" and config.focusable ~= false
end

local function focus_floating_window()
  local current_win = vim.api.nvim_get_current_win()

  -- `nvim_list_wins()` includes floating windows. Iterate backwards so the
  -- newest/topmost hover or diagnostic float wins when several are open.
  local windows = vim.api.nvim_list_wins()
  for i = #windows, 1, -1 do
    local win = windows[i]
    if win ~= current_win and is_focusable_floating_window(win) then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end

  return false
end

local function jump_diagnostic(count)
  vim.diagnostic.jump({
    count = count,
    on_jump = function(diagnostic, bufnr)
      if diagnostic then
        show_diagnostic_float(bufnr, "cursor")
      end
    end,
  })
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local hover_cycle = {
      bufnr = nil,
      lnum = nil,
      state = "off",
    }

    local function reset_hover_cycle()
      hover_cycle = {
        bufnr = nil,
        lnum = nil,
        state = "off",
      }
    end

    local function is_same_line(cursor)
      return hover_cycle.bufnr == event.buf
          and hover_cycle.lnum == cursor[1]
    end

    local function has_diagnostic_on_line(bufnr, cursor)
      -- `lnum` filters diagnostics spanning this 0-indexed line. Keep K's
      -- diagnostic half line-based instead of duplicating open_float's
      -- character-position filtering. See :help vim.diagnostic.GetOpts and
      -- :help vim.diagnostic.Opts.Float.
      return next(vim.diagnostic.get(bufnr, { lnum = cursor[1] - 1 })) ~= nil
    end

    local function has_floating_window()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
          return true
        end
      end
      return false
    end

    local function close_floating_windows()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
          pcall(vim.api.nvim_win_close, win, false)
        end
      end
    end

    local hover_cycle_group = vim.api.nvim_create_augroup("UserLspHoverCycle" .. event.buf, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
      group = hover_cycle_group,
      buffer = event.buf,
      callback = function(args)
        if hover_cycle.state == "off" then
          return
        end

        if args.event == "BufLeave" then
          reset_hover_cycle()
          return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        if not is_same_line(cursor) then
          reset_hover_cycle()
        end
      end,
      desc = "Reset K hover cycle when leaving the popup line",
    })

    vim.keymap.set("n", "K", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local same_line = is_same_line(cursor)
      if same_line and hover_cycle.state ~= "off" and not has_floating_window() then
        reset_hover_cycle()
        same_line = false
      end
      local has_diagnostic = has_diagnostic_on_line(event.buf, cursor)

      if not same_line then
        hover_cycle = {
          bufnr = event.buf,
          lnum = cursor[1],
          state = has_diagnostic and "diagnostic" or "hover",
        }
      elseif has_diagnostic then
        if hover_cycle.state == "diagnostic" then
          hover_cycle.state = "hover"
        elseif hover_cycle.state == "hover" then
          hover_cycle.state = "off"
        else
          hover_cycle.state = "diagnostic"
        end
      elseif hover_cycle.state == "hover" then
        hover_cycle.state = "off"
      else
        hover_cycle.state = "hover"
      end

      close_floating_windows()

      if hover_cycle.state == "diagnostic" then
        show_diagnostic_float(event.buf, "line")
      elseif hover_cycle.state == "hover" then
        show_hover()
      end
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Cycle diagnostic and hover",
    })

    vim.keymap.set("n", "<M-w>", function()
      if focus_floating_window() then
        return
      end

      vim.cmd.wincmd("w")
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Focus hover/diagnostic window or cycle windows",
    })

    -- why do I need this when K does the same thing?
    -- vim.keymap.set("n", "gK", show_hover, {
    --   buffer = event.buf,
    --   silent = true,
    --   desc = "Show hover documentation",
    -- })

    -- can just ctrl w - w
    -- vim.keymap.set("n", "<leader><down>", focus_floating_window, {
    --   buffer = event.buf,
    --   silent = true,
    --   desc = "Focus hover/diagnostic window",
    -- })

    vim.keymap.set("n", "]d", function()
      jump_diagnostic(1)
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Next diagnostic",
    })

    vim.keymap.set("n", "[d", function()
      jump_diagnostic(-1)
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Previous diagnostic",
    })
  end,
})

vim.lsp.enable("lua_ls")
vim.lsp.enable("basedpyright")
vim.lsp.enable("ruff")
vim.lsp.enable("vtsls")
vim.lsp.enable('eslint')
vim.lsp.enable('bashls')
vim.lsp.enable('gopls')
vim.lsp.enable('jdtls')
