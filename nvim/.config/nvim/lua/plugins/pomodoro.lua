local function refresh_lualine()
  require("config.statusline").refresh()
end

local BreakNotifier = {}

function BreakNotifier.new(timer, opts)
  return setmetatable({
    timer = timer,
    opts = opts or {},
  }, { __index = BreakNotifier })
end

function BreakNotifier:start()
  refresh_lualine()
end

function BreakNotifier:tick(_)
  refresh_lualine()
end

function BreakNotifier:stop()
  refresh_lualine()
end

function BreakNotifier:done()
  refresh_lualine()

  local name = self.timer.name or ""
  if name:lower():find("break") then
    return
  end

  vim.schedule(function()
    local ok, err = pcall(vim.cmd, "CellularAutomaton make_it_rain")
    if not ok then
      vim.notify("Could not make it rain: " .. tostring(err), vim.log.levels.WARN, { title = "pomodoro" })
    end
  end)
end

local function start_custom_timer()
  vim.ui.input({ prompt = "Timer duration (e.g. 25m): " }, function(duration)
    duration = duration and vim.trim(duration) or ""
    if duration == "" then
      return
    end

    vim.ui.input({ prompt = "Timer name: ", default = "" }, function(name)
      if name == nil then
        return
      end

      local args = { duration }
      name = vim.trim(name)
      if name ~= "" then
        args[#args + 1] = name
      end

      vim.api.nvim_cmd({ cmd = "TimerStart", args = args }, {})
    end)
  end)
end

return {
  "epwalsh/pomo.nvim",
  version = "*",
  cmd = {
    "TimerStart",
    "TimerStop",
    "TimerRepeat",
    "TimerSession",
    "TimerHide",
    "TimerShow",
    "TimerPause",
    "TimerResume",
  },
  dependencies = {
    "eandrju/cellular-automaton.nvim",
  },
  opts = {
    update_interval = 1000,
    notifiers = {
      {
        name = "Default",
        opts = {
          sticky = false,
          title_icon = "󱎫",
          text_icon = "󰄉",
        },
      },
      { name = "System" },
      { init = BreakNotifier.new },
    },
    sessions = {
      four_rounds = {
        { name = "Work", duration = "25m" },
        { name = "Short Break", duration = "5m" },
        { name = "Work", duration = "25m" },
        { name = "Short Break", duration = "5m" },
        { name = "Work", duration = "25m" },
        { name = "Short Break", duration = "5m" },
        { name = "Work", duration = "25m" },
        { name = "Long Break", duration = "15m" },
      },
    },
  },
  keys = {
    { "<leader>Ts", "<cmd>TimerStart 25m Work<CR>", desc = "Timer: start work" },
    { "<leader>Tx", "<cmd>TimerStop<CR>", desc = "Timer: stop latest" },
    { "<leader>Tc", start_custom_timer, desc = "Timer: custom" },
    { "<leader>T4", "<cmd>TimerSession four_rounds<CR>", desc = "Timer: 4 rounds" },
  },
}
