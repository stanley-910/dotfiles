local lsp_group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })

vim.diagnostic.config({
  signs = false,
  underline = true,
  update_in_insert = true,
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

local function focus_floating_window()
  local windows = vim.api.nvim_list_wins()

  for i = #windows, 1, -1 do
    local win = windows[i]
    if vim.api.nvim_win_is_valid(win) then
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= "" and config.focusable ~= false then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  vim.notify("No focusable hover/diagnostic window", vim.log.levels.INFO)
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
      col = nil,
      state = "off",
    }

    local function reset_hover_cycle()
      hover_cycle = {
        bufnr = nil,
        lnum = nil,
        col = nil,
        state = "off",
      }
    end

    local function is_same_spot(cursor)
      return hover_cycle.bufnr == event.buf
          and hover_cycle.lnum == cursor[1]
          and hover_cycle.col == cursor[2]
    end

    local function diagnostic_at_cursor(bufnr)
      local cursor = vim.api.nvim_win_get_cursor(0)
      local lnum = cursor[1] - 1
      local col = cursor[2]

      for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
        local start_col = diagnostic.col or 0
        local end_col = diagnostic.end_col or start_col + 1

        if col >= start_col and col <= end_col then
          return diagnostic
        end
      end
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
        if not is_same_spot(cursor) then
          reset_hover_cycle()
        end
      end,
      desc = "Reset K hover cycle when leaving the popup anchor",
    })

    vim.keymap.set("n", "K", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local same_spot = is_same_spot(cursor)
      if same_spot and hover_cycle.state ~= "off" and not has_floating_window() then
        reset_hover_cycle()
        same_spot = false
      end
      local has_diagnostic = diagnostic_at_cursor(event.buf) ~= nil

      if not same_spot then
        hover_cycle = {
          bufnr = event.buf,
          lnum = cursor[1],
          col = cursor[2],
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
        show_diagnostic_float(event.buf, "cursor")
      elseif hover_cycle.state == "hover" then
        show_hover()
      end
    end, {
      buffer = event.buf,
      silent = true,
      desc = "Cycle diagnostic and hover",
    })

    vim.keymap.set("n", "gK", show_hover, {
      buffer = event.buf,
      silent = true,
      desc = "Show hover documentation",
    })

    vim.keymap.set("n", "<leader><down>", focus_floating_window, {
      buffer = event.buf,
      silent = true,
      desc = "Focus hover/diagnostic window",
    })

    vim.keymap.set("n", "grr", "<cmd>Trouble lsp_references open focus=true<CR>", {
      buffer = event.buf,
      silent = true,
      desc = "References (Trouble)",
    })

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
