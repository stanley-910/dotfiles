local M = {}

local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

local function brighten(hex, toward, amount)
  local r1, g1, b1 = hex_to_rgb(hex)
  local r2, g2, b2 = hex_to_rgb(toward)
  return rgb_to_hex(
    math.floor(r1 + (r2 - r1) * amount + 0.5),
    math.floor(g1 + (g2 - g1) * amount + 0.5),
    math.floor(b1 + (b2 - b1) * amount + 0.5)
  )
end

local function highlight_fg(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl and hl.fg then
    return string.format("#%06x", hl.fg)
  end
end

function M.setup_highlights(p)
  local comment = highlight_fg("Comment") or p.fujiGray or "#727169"
  local foreground = highlight_fg("Normal") or p.oldWhite or "#c8c093"

  vim.api.nvim_set_hl(0, "StatusLinePath", {
    fg = brighten(comment, foreground, 0.22),
  })
end

function M.refresh()
  vim.schedule(function()
    local ok, lualine = pcall(require, "lualine")
    if ok then
      pcall(lualine.refresh)
    end
  end)
end

local function project_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    return vim.fs.root(name, ".git") or vim.fn.getcwd()
  end

  return vim.fs.root(bufnr, ".git") or vim.fn.getcwd()
end

local function with_trailing_slash(path)
  return path:gsub("/+$", "") .. "/"
end

function M.buffer_directory()
  return {
    function()
      if vim.bo.buftype ~= "" then
        return ""
      end

      local name = vim.api.nvim_buf_get_name(0)
      if name == "" then
        return "[No Name]"
      end

      local dir = vim.fs.dirname(vim.fs.abspath(name))
      if not dir then
        return ""
      end

      local root = vim.fs.abspath(project_root(0))
      local rel = vim.fs.relpath(root, dir)
      if rel == nil then
        return with_trailing_slash(vim.fn.fnamemodify(dir, ":~"))
      end

      if rel == "" or rel == "." then
        return "./"
      end

      return with_trailing_slash(rel)
    end,
    icon = "",
    color = "StatusLinePath",
  }
end

function M.searchcount(p)
  return {
    function()
      local sc = vim.fn.searchcount({ maxcount = 999 })
      if not sc.total or sc.total == 0 then
        return ""
      end
      if sc.incomplete == 1 then
        return "[?/?]"
      end
      return string.format("[%d/%d]", sc.current, sc.total)
    end,
    cond = function()
      return vim.v.hlsearch == 1
    end,
    icon = "",
    color = { fg = p.carpYellow },
  }
end

function M.recording(p)
  return {
    function()
      return "REC @" .. vim.fn.reg_recording()
    end,
    cond = function()
      return vim.fn.reg_recording() ~= ""
    end,
    color = { fg = p.samuraiRed, gui = "bold" },
  }
end

function M.lsp(p)
  return {
    function()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      local names = {}
      for _, c in ipairs(clients) do
        names[#names + 1] = c.name
      end
      return table.concat(names, " ")
    end,
    cond = function()
      return #vim.lsp.get_clients({ bufnr = 0 }) > 0
    end,
    icon = "",
    padding = { left = 0, right = 1 },
    color = { fg = p.springGreen },
  }
end

function M.session_autosave(p)
  return {
    function()
      local sessions = require("config.sessions")
      return sessions.is_active() and "sesh:on" or "sesh:off"
    end,
    icon = "",
    padding = { left = 0, right = 1 },
    color = function()
      local sessions = require("config.sessions")
      if sessions.is_active() then
        return { fg = p.springGreen, gui = "bold" }
      end
      return { fg = p.fujiGray }
    end,
  }
end

function M.pomodoro(p)
  return {
    function()
      local pomo = package.loaded["pomo"]
      if not pomo then
        return ""
      end

      local timer = pomo.get_first_to_finish()
      if not timer then
        return ""
      end

      return "󰄉 " .. tostring(timer)
    end,
    cond = function()
      local pomo = package.loaded["pomo"]
      return pomo and pomo.get_first_to_finish() ~= nil
    end,
    icon = "",
    padding = { left = 0, right = 1 },
    color = { fg = p.carpYellow, gui = "bold" },
  }
end

function M.mode()
  return {
    "mode",
    fmt = function(mode)
      if mode == "COMMAND" then
        local cmdtype = vim.fn.getcmdtype()

        if cmdtype == "/" then
          return "SEARCH"
        elseif cmdtype == "?" then
          return "R-SEARCH"
        end
      end
      return mode
    end,
  }
end

function M.dashboard_extension(p)
  return {
    filetypes = { "snacks_dashboard" },
    sections = {
      lualine_a = {
        {
          function()
            return "DASH"
          end,
          color = { fg = p.sumiInk0, bg = p.carpYellow, gui = "bold" },
        },
      },
      lualine_b = {
        {
          function()
            return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
          end,
          color = { fg = p.springViolet2 },
        },
      },
    },
  }
end

function M.setup_autocmds()
  -- FRAGILE SEAM: lualine does not redraw the statusline when a macro
  -- recording starts/stops, so the REC indicator would lag up to the refresh
  -- interval. Force an immediate refresh. RecordingLeave fires while
  -- reg_recording() is STILL set, so defer one tick to read the cleared
  -- value. Delete this block if a future nvim redraws on these events.
  local rec_group = vim.api.nvim_create_augroup("LualineRecording", { clear = true })
  vim.api.nvim_create_autocmd("RecordingEnter", {
    group = rec_group,
    callback = M.refresh,
  })
  vim.api.nvim_create_autocmd("RecordingLeave", {
    group = rec_group,
    callback = function()
      vim.defer_fn(M.refresh, 50)
    end,
  })

  local session_group = vim.api.nvim_create_augroup("LualineSessionAutosave", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = session_group,
    pattern = "SessionStateChanged",
    callback = M.refresh,
  })
end

return M
