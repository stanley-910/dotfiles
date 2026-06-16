-- Persist nvim-dap breakpoints with small, conservative line relocation.
--
-- Design references:
-- - nvim-dap keeps the source of truth in require("dap.breakpoints"); use its
--   get()/set() API instead of touching signs directly. See :help dap.txt.
-- - Load lazily on BufReadPost, the same practical shape used by
--   persistent-breakpoints.nvim, so restoring a project does not force-open files.
-- - Store under stdpath("state"): this is local editor state, not dotfile config.
-- - Relocate only by exact trimmed source text plus nearby context. No fuzzy
--   guessing: stale breakpoints should be obvious, not silently wrong.

local M = {}

local defaults = {
  save_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "dap-breakpoints"),
  context_lines = 2,
  search_radius = 80,
  notify = true,
}

local config = vim.deepcopy(defaults)
local data ---@type table?
local data_path ---@type string?
local loaded_files = {} ---@type table<string, boolean>

local function notify(message, level)
  if config.notify then
    vim.notify(message, level or vim.log.levels.INFO)
  end
end

local function project_key()
  local cwd = vim.fn.getcwd()
  return cwd, vim.fn.sha256(cwd)
end

local function storage_path()
  local cwd, key = project_key()
  local path = vim.fs.joinpath(config.save_dir, key .. ".json")

  if path ~= data_path then
    data = nil
    data_path = path
    loaded_files = {}
  end

  return path, cwd
end

local function normalize(line)
  return vim.trim(line or "")
end

local function line_at(bufnr, lnum)
  if lnum < 1 or lnum > vim.api.nvim_buf_line_count(bufnr) then
    return ""
  end

  return vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
end

local function buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

local function read_json(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local raw = file:read("*a")
  file:close()

  if raw == "" then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    notify("Could not read DAP breakpoints: " .. path, vim.log.levels.WARN)
    return nil
  end

  return decoded
end

local function write_json(path, value)
  vim.fn.mkdir(vim.fs.dirname(path), "p")

  local tmp = path .. ".tmp"
  local file, open_err = io.open(tmp, "w")
  if not file then
    notify("Could not save DAP breakpoints: " .. tostring(open_err), vim.log.levels.WARN)
    return false
  end

  file:write(vim.json.encode(value))
  file:close()

  local ok, err = vim.uv.fs_rename(tmp, path)
  if not ok then
    notify("Could not save DAP breakpoints: " .. tostring(err), vim.log.levels.WARN)
  end

  return ok
end

local function store()
  local path, cwd = storage_path()
  data = data or read_json(path) or { version = 1, cwd = cwd, files = {} }
  data.version = 1
  data.cwd = cwd
  data.files = data.files or {}
  return data, path
end

local function nearby_context(bufnr, lnum, step)
  local result = {}
  local count = vim.api.nvim_buf_line_count(bufnr)
  local current = lnum + step

  while current >= 1 and current <= count and #result < config.context_lines do
    local text = normalize(line_at(bufnr, current))
    if text ~= "" then
      result[#result + 1] = text
    end
    current = current + step
  end

  return result
end

local function serialize_breakpoint(bufnr, breakpoint)
  local lnum = breakpoint.line

  return {
    line = lnum,
    text = normalize(line_at(bufnr, lnum)),
    before = nearby_context(bufnr, lnum, -1),
    after = nearby_context(bufnr, lnum, 1),
    condition = breakpoint.condition,
    hitCondition = breakpoint.hitCondition,
    logMessage = breakpoint.logMessage,
  }
end

local function score_context(bufnr, lnum, record)
  local score = 0

  for index, text in ipairs(record.before or {}) do
    if normalize(line_at(bufnr, lnum - index)) == text then
      score = score + (config.context_lines + 1 - index)
    end
  end

  for index, text in ipairs(record.after or {}) do
    if normalize(line_at(bufnr, lnum + index)) == text then
      score = score + (config.context_lines + 1 - index)
    end
  end

  return score
end

local function relocate_line(bufnr, record)
  local count = vim.api.nvim_buf_line_count(bufnr)
  local original = math.min(math.max(record.line or 1, 1), count)
  local text = normalize(record.text)

  if text == "" then
    return original
  end

  if normalize(line_at(bufnr, original)) == text then
    return original
  end

  local candidates = {}

  local function collect(first, last)
    for lnum = first, last do
      if normalize(line_at(bufnr, lnum)) == text then
        candidates[#candidates + 1] = {
          line = lnum,
          score = score_context(bufnr, lnum, record),
          distance = math.abs(lnum - original),
        }
      end
    end
  end

  collect(math.max(1, original - config.search_radius), math.min(count, original + config.search_radius))

  if #candidates == 0 then
    collect(1, count)
  end

  if #candidates == 0 then
    return original
  end

  table.sort(candidates, function(left, right)
    if left.score ~= right.score then
      return left.score > right.score
    end
    return left.distance < right.distance
  end)

  -- Avoid a silent bad move when the whole-file search found repeated lines
  -- without any matching context. In that case, keep the old line number and let
  -- nvim-dap/debugpy mark it rejected if it no longer binds.
  if #candidates > 1 and candidates[1].score == 0 and candidates[2].score == 0 then
    return original
  end

  return candidates[1].line
end

function M.save()
  local breakpoints = require("dap.breakpoints")
  local current = breakpoints.get()
  local persisted, path = store()
  local files = vim.deepcopy(persisted.files or {})

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local file = buffer_path(bufnr)
      if file then
        files[file] = nil
      end
    end
  end

  for bufnr, buffer_breakpoints in pairs(current) do
    local file = buffer_path(bufnr)
    if file and #buffer_breakpoints > 0 then
      files[file] = vim.tbl_map(function(breakpoint)
        return serialize_breakpoint(bufnr, breakpoint)
      end, buffer_breakpoints)
    end
  end

  persisted.files = files
  write_json(path, persisted)
end

function M.load_for_buffer(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local file = buffer_path(bufnr)
  local already_loaded = file and loaded_files[file] and not opts.force
  if not file or already_loaded then
    return
  end

  local persisted = store()
  local records = persisted.files[file]
  if type(records) ~= "table" or vim.tbl_isempty(records) then
    loaded_files[file] = true
    return
  end

  local breakpoints = require("dap.breakpoints")
  local existing = {}
  for _, breakpoint in ipairs(breakpoints.get(bufnr)[bufnr] or {}) do
    existing[breakpoint.line] = true
  end

  local restored = 0
  for _, record in ipairs(records) do
    local lnum = relocate_line(bufnr, record)
    if not existing[lnum] then
      breakpoints.set({
        condition = record.condition,
        hit_condition = record.hitCondition,
        log_message = record.logMessage,
      }, bufnr, lnum)
      existing[lnum] = true
      restored = restored + 1
    end
  end

  loaded_files[file] = true

  if opts.force then
    notify(("Restored %d DAP breakpoint(s)"):format(restored))
  end
end

function M.load_all(opts)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.load_for_buffer(bufnr, opts)
  end
end

local function breakpoint_at(bufnr, lnum)
  for _, breakpoint in ipairs(require("dap.breakpoints").get(bufnr)[bufnr] or {}) do
    if breakpoint.line == lnum then
      return breakpoint
    end
  end
end

local function breakpoint_details(breakpoint)
  local details = {}

  if breakpoint.state and breakpoint.state.verified == false then
    details[#details + 1] = "rejected"
  end
  if breakpoint.condition and breakpoint.condition ~= "" then
    details[#details + 1] = "condition: " .. breakpoint.condition
  end
  if breakpoint.hitCondition and breakpoint.hitCondition ~= "" then
    details[#details + 1] = "hit: " .. breakpoint.hitCondition
  end
  if breakpoint.logMessage and breakpoint.logMessage ~= "" then
    details[#details + 1] = "log: " .. breakpoint.logMessage
  end

  return details
end

function M.items()
  local items = {}

  for bufnr, buffer_breakpoints in pairs(require("dap.breakpoints").get()) do
    local file = buffer_path(bufnr)

    if file then
      for _, breakpoint in ipairs(buffer_breakpoints) do
        local line = normalize(line_at(bufnr, breakpoint.line))
        local details = breakpoint_details(breakpoint)
        local suffix = #details > 0 and ("[" .. table.concat(details, ", ") .. "]") or ""

        items[#items + 1] = {
          file = file,
          buf = bufnr,
          pos = { breakpoint.line, 0 },
          text = ("%s:%d %s %s"):format(vim.fn.fnamemodify(file, ":~:."), breakpoint.line, line, suffix),
          line = line,
          comment = suffix ~= "" and suffix or nil,
          breakpoint = breakpoint,
        }
      end
    end
  end

  table.sort(items, function(left, right)
    if left.file == right.file then
      return left.pos[1] < right.pos[1]
    end
    return left.file < right.file
  end)

  return items
end

function M.jump(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer_breakpoints = require("dap.breakpoints").get(bufnr)[bufnr] or {}

  if #buffer_breakpoints == 0 then
    notify("No DAP breakpoints in current buffer")
    return
  end

  table.sort(buffer_breakpoints, function(left, right)
    return left.line < right.line
  end)

  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target

  if direction > 0 then
    for _, breakpoint in ipairs(buffer_breakpoints) do
      if breakpoint.line > current_line then
        target = breakpoint
        break
      end
    end
    target = target or buffer_breakpoints[1]
  else
    for index = #buffer_breakpoints, 1, -1 do
      local breakpoint = buffer_breakpoints[index]
      if breakpoint.line < current_line then
        target = breakpoint
        break
      end
    end
    target = target or buffer_breakpoints[#buffer_breakpoints]
  end

  vim.api.nvim_win_set_cursor(0, { target.line, 0 })
  vim.cmd("normal! zz")
end

function M.pick()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    notify("snacks.nvim is not installed", vim.log.levels.WARN)
    return
  end

  local items = M.items()
  if #items == 0 then
    notify("No DAP breakpoints")
    return
  end

  snacks.picker.pick({
    title = "DAP Breakpoints",
    items = items,
    format = "file",
    preview = "file",
    confirm = "edit",
  })
end

function M.inspect_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local breakpoint = breakpoint_at(bufnr, lnum)

  if not breakpoint then
    notify("No DAP breakpoint on current line")
    return
  end

  local state = breakpoint.state or {}
  local lines = {
    ("%s:%d"):format(vim.fn.fnamemodify(buffer_path(bufnr) or "", ":~:."), lnum),
    "condition: " .. (breakpoint.condition or "<none>"),
    "hit condition: " .. (breakpoint.hitCondition or "<none>"),
    "log message: " .. (breakpoint.logMessage or "<none>"),
    "verified: " .. (state.verified == nil and "unknown" or tostring(state.verified)),
  }

  if state.message then
    lines[#lines + 1] = "message: " .. state.message
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "DAP Breakpoint" })
end

function M.toggle()
  require("dap").toggle_breakpoint()
  M.save()
end

local function input_value(value)
  return value ~= "" and value or nil
end

function M.set_conditional()
  local existing = breakpoint_at(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1])

  vim.ui.input({
    prompt = "Breakpoint condition: ",
    default = existing and existing.condition or "",
  }, function(condition)
    if condition == nil then
      return
    end

    require("dap").set_breakpoint(
      input_value(condition),
      existing and existing.hitCondition or nil,
      existing and existing.logMessage or nil
    )
    M.save()
  end)
end

function M.set_hit_condition()
  local existing = breakpoint_at(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1])

  vim.ui.input({
    prompt = "Hit condition: ",
    default = existing and existing.hitCondition or "",
  }, function(hit_condition)
    if hit_condition == nil then
      return
    end

    require("dap").set_breakpoint(
      existing and existing.condition or nil,
      input_value(hit_condition),
      existing and existing.logMessage or nil
    )
    M.save()
  end)
end

function M.set_log_point()
  local existing = breakpoint_at(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1])

  vim.ui.input({
    prompt = "Logpoint message: ",
    default = existing and existing.logMessage or "",
  }, function(message)
    if message == nil then
      return
    end

    require("dap").set_breakpoint(
      existing and existing.condition or nil,
      existing and existing.hitCondition or nil,
      input_value(message)
    )
    M.save()
  end)
end

function M.clear_all()
  require("dap").clear_breakpoints()
  local persisted, path = store()
  persisted.files = {}
  write_json(path, persisted)
  notify("Cleared saved DAP breakpoints")
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("UserDapBreakpoints", { clear = true })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(event)
      M.load_for_buffer(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.save,
  })

  vim.api.nvim_create_user_command("DapBreakpointsSave", M.save, { desc = "Save DAP breakpoints" })
  vim.api.nvim_create_user_command("DapBreakpointsLoad", function()
    M.load_all({ force = true })
  end, { desc = "Load DAP breakpoints" })
  vim.api.nvim_create_user_command("DapBreakpointsClearSaved", M.clear_all, { desc = "Clear saved DAP breakpoints" })

  M.load_all()
end

return M
