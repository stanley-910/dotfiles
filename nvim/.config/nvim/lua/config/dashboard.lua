-- "Ledger" dashboard for Snacks.dashboard — a pure-typography, dot-leader,
-- two-pane start screen with a MODULAR right column. Recreated from the design
-- handoff in ~/Downloads/design_handoff_nvim_dashboard (HTML prototype; this is
-- a from-scratch Lua implementation, not a port).
--
-- Wiring: lua/plugins/snacks.lua sets `dashboard.sections` to a function that
-- requires this file, so nothing here loads unless the dashboard actually opens.
--
-- Layout (each pane is `opts.width` cols, separated by snacks' pane_gap):
--   pane 1: header ── rule ── JUMP (single-key actions) ── RECENT ── tip
--   pane 2: clock  ── rule ── module stack (opts.modules) ── lazy stats
--
-- Modules are independently toggleable in `M.opts.modules` below. Async modules
-- (git/sys/weather/music/github) render a placeholder first, fill in via
-- vim.system callbacks + Snacks.dashboard.update(), and reserve their line
-- count so the layout never reflows.
--
-- SKELETONS (wired but waiting on infrastructure — see each site):
--   * jump `s` restore session  -> needs a session plugin (folke/persistence.nvim)
--   * jump `p` browse projects  -> needs a projects picker
--   * jump `g` lazygit          -> needs the lazygit binary (brew install lazygit)
--   * github module             -> gh auth for live contribution heatmap/stats
--
-- FRAGILE: the vertical pane divider hooks the SnacksDashboardUpdatePost User
-- event (fired by snacks/dashboard.lua D.fire, but undocumented) and draws
-- via extmark virt_text overlays. NEVER draw decorations with
-- nvim_buf_set_lines here — rewriting a rendered line destroys snacks'
-- highlight extmarks on it (everything on the line turns white).

local M = {}

-- ---------------------------------------------------------------------------
-- OPTS — the tweak surface. Everything user-tunable lives in this table.
-- ---------------------------------------------------------------------------

M.opts = {
  -- per-pane width. `width` is the LIVE value, recomputed responsively each
  -- render in sections() (clamped down to fit the window); `width_max` is the
  -- ceiling. width_max should match dashboard.width in snacks.lua.
  width = 52,
  width_max = 52,
  gap = 1,             -- blank lines between JUMP/RECENT rows (0 = compact)
  narrow_top_pad = 3,  -- blank rows above the header in single-column mode only
  recent_limit = 5,

  -- Accent: kanagawa palette name. Alternates from the design:
  -- "carpYellow" | "crystalBlue" | "sakuraPink" | "waveAqua2"
  accent = "carpYellow",

  -- Right-column module stack, in render order. Flip to false to hide.
  modules = {
    { "status",  true },
    { "music",   true },
    { "github",  true },
    { "commits", true },
    { "theme",   true },
    { "system",  false },
    { "todos",   false },
    { "lazy",    false },
  },

  -- Obsidian vault (codex-cloud). Feeds the todos module and STATUS's `obs`
  -- row. Daily notes follow the vault's daily-notes.json: format YYYY-MM-DD
  -- under 01-personal/<year>/<Month>/. Renders "no daily note" on days
  -- without one.
  vault = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/codex-cloud"),
  daily_note = function()
    return M.opts.vault
        .. ("/01-personal/%s/%s/%s.md"):format(os.date("%Y"), os.date("%B"), os.date("%Y-%m-%d"))
  end,

  weather_ttl = 30 * 60, -- seconds; weather is also file-cached across sessions
  github_login = "stanley-910",
  github_ttl = 15 * 60,  -- seconds between GitHub tracker refreshes
  github_weeks = 14,     -- real contribution window; grid extends to pane width with gray filler
  music_poll = 5,        -- seconds between MUSIC refreshes while the dashboard is open

  -- Footer tip: a daily-rotating `:h <topic>` pulled from nvim's own docs
  -- (option list + nvim_*/vim.* tags), so every day surfaces one core thing
  -- to read. `h` on the dashboard opens it. See tip_of_the_day() below.
}

-- ---------------------------------------------------------------------------
-- Highlights — resolved from the kanagawa palette at runtime (per the handoff:
-- no hardcoded hex). Falls back to links so a switched colorscheme (via the
-- THEME module's `t` picker) still looks coherent.
-- ---------------------------------------------------------------------------

local function set_hl()
  local hl = function(name, def)
    vim.api.nvim_set_hl(0, name, def)
  end
  local on_kanagawa = (vim.g.colors_name or ""):find("kanagawa") ~= nil
  local ok, colors = pcall(function()
    return require("kanagawa.colors").setup({ theme = "wave" })
  end)
  if on_kanagawa and ok then
    local p = colors.palette
    hl("DashTop", { fg = p.fujiWhite, bold = true })     -- top header, heavier terminal face
    hl("DashTopMuted", { fg = p.fujiGray, bold = true }) -- top header metadata
    hl("DashHeader", { fg = p.fujiWhite })               -- primary text
    hl("DashText", { fg = p.oldWhite })                  -- secondary text
    hl("DashSection", { fg = p.fujiGray })               -- CAPS section labels
    hl("DashMuted", { fg = p.fujiGray })
    hl("DashDots", { fg = p.sumiInk6 })                  -- dot leaders
    hl("DashRule", { fg = p.sumiInk5 })                  -- horizontal rules
    hl("DashKey", { fg = p.springViolet1 })              -- keybind hints
    hl("DashAccent", { fg = p[M.opts.accent] or p.carpYellow })
    hl("DashGitMod", { fg = p.autumnYellow })
    hl("DashDone", { fg = p.springGreen })
    hl("DashWarn", { fg = p.roninYellow })
    hl("DashHeat0", { fg = p.sumiInk4 or p.sumiInk5 })
    hl("DashHeat1", { fg = p.winterGreen or p.springGreen })
    hl("DashHeat2", { fg = "#3e5435" })
    hl("DashHeat3", { fg = p.autumnGreen or p.springGreen })
    hl("DashHeat4", { fg = p.springGreen })
  else
    hl("DashTop", { link = "Normal", bold = true })
    hl("DashTopMuted", { link = "Comment", bold = true })
    hl("DashHeader", { link = "Normal" })
    hl("DashText", { link = "Normal" })
    hl("DashSection", { link = "Comment" })
    hl("DashMuted", { link = "Comment" })
    hl("DashDots", { link = "NonText" })
    hl("DashRule", { link = "WinSeparator" })
    hl("DashKey", { link = "Number" })
    hl("DashAccent", { link = "Special" })
    hl("DashGitMod", { link = "DiagnosticWarn" })
    hl("DashDone", { link = "DiagnosticOk" })
    hl("DashWarn", { link = "DiagnosticWarn" })
    hl("DashHeat0", { link = "NonText" })
    hl("DashHeat1", { link = "DiagnosticHint" })
    hl("DashHeat2", { link = "DiagnosticInfo" })
    hl("DashHeat3", { link = "DiagnosticWarn" })
    hl("DashHeat4", { link = "DiagnosticOk" })
  end
end

-- ---------------------------------------------------------------------------
-- Text helpers. A snacks "Text" is { "string", hl = group, width?, align? };
-- an item's `text` is a list of those, concatenated on one line (\n splits).
-- ---------------------------------------------------------------------------

local function strw(s)
  return vim.api.nvim_strwidth(s)
end

local function truncate(s, max)
  if strw(s) <= max then
    return s
  end
  return vim.fn.strcharpart(s, 0, math.max(max - 1, 0)) .. "…"
end

-- Build one ledger row exactly opts.width cols wide:
--   <left segments> <fill fill fill> <right segments>
-- fill defaults to the dot leader; pass " " for plain space alignment.
local function row(left, right, fill)
  fill = fill or "."
  local used = 0
  for _, t in ipairs(left) do
    used = used + strw(t[1])
  end
  for _, t in ipairs(right) do
    used = used + strw(t[1])
  end
  local pad = M.opts.width - used - 2
  local out = {}
  vim.list_extend(out, left)
  if pad >= 1 then
    out[#out + 1] = { " " .. string.rep(fill, pad) .. " ", hl = "DashDots" }
  else
    out[#out + 1] = { " ", hl = "DashDots" }
  end
  vim.list_extend(out, right)
  return out
end

-- Section title row: CAPS label left, muted meta right-aligned (space fill).
local function title(label, meta)
  return {
    text = row({ { label, hl = "DashSection" } }, meta or {}, " "),
    padding = 1, -- one blank line between the label and its content
  }
end

local function rel_age(secs)
  local d = os.time() - secs
  if d < 60 then
    return "now"
  elseif d < 3600 then
    return math.floor(d / 60) .. "m"
  elseif d < 86400 then
    return math.floor(d / 3600) .. "h"
  elseif d < 7 * 86400 then
    return math.floor(d / 86400) .. "d"
  end
  return math.floor(d / (7 * 86400)) .. "w"
end

-- Compress `git log %cr` ("2 hours ago") to ledger style ("2h").
local function short_age(cr)
  local n, unit = (cr or ""):match("(%d+)%s+(%a+)")
  if not n then
    return cr or ""
  end
  local map = {
    second = "s",
    seconds = "s",
    minute = "m",
    minutes = "m",
    hour = "h",
    hours = "h",
    day = "d",
    days = "d",
    week = "w",
    weeks = "w",
    month = "mo",
    months = "mo",
    year = "y",
    years = "y",
  }
  return n .. (map[unit] or "")
end

-- ---------------------------------------------------------------------------
-- Async engine. Renderers stay synchronous: async(id, ...) returns the cached
-- result (or nil -> render a placeholder) and kicks off at most one job; when
-- the job lands it stores the result and calls Snacks.dashboard.update(),
-- which re-runs sections() and picks the value up from the cache.
-- ---------------------------------------------------------------------------

local jobs = {} ---@type table<string, {result?:any, time?:number, running:boolean}>
local music_playing = false -- set by the music fetch/poll; drives the visualizer

local function async(id, ttl, start)
  local j = jobs[id]
  if j and (j.running or (j.time and os.time() - j.time < ttl)) then
    return j.result
  end
  jobs[id] = { running = true, result = j and j.result, time = j and j.time }
  start(function(result)
    jobs[id] = { result = result, time = os.time(), running = false }
    pcall(function()
      Snacks.dashboard.update()
    end)
  end)
  return jobs[id].result
end

-- Run `cmd`, parse stdout into renderable Text lines ON THE MAIN LOOP
-- (vim.system callbacks are fast-event context where nvim_strwidth etc. are
-- not allowed — hence the schedule_wrap).
local function shell(id, ttl, cmd, parse)
  return async(id, ttl, function(done)
    local ok = pcall(vim.system, cmd, { text = true }, vim.schedule_wrap(function(out)
      done(parse(out.code == 0 and out.stdout or nil))
    end))
    if not ok then
      done(nil)
    end
  end)
end

local function pending()
  return { { "…", hl = "DashMuted" } }
end

-- ---------------------------------------------------------------------------
-- JUMP actions. Single-key, dashboard-local. Hints show the real global maps
-- where one exists (keymap.lua / quickbind); otherwise the dashboard key.
-- ---------------------------------------------------------------------------

local function pick(picker, picker_opts)
  return function()
    local pickers = Snacks.picker
    local fn = pickers and pickers[picker]
    if fn then
      fn(picker_opts or {})
    else
      vim.notify("Snacks picker '" .. picker .. "' is not available", vim.log.levels.WARN)
    end
  end
end

local function stub(msg)
  return function()
    vim.notify(msg, vim.log.levels.WARN, { title = "dashboard" })
  end
end

local jump_actions = {
  { key = "f", label = "find file",      hint = "SPC SPC", action = pick("files") },
  { key = "/", label = "grep project",   hint = "SPC /",   action = pick("grep") },
  { key = "n", label = "scratch buffer", hint = "n",       action = ":enew" },
  { key = "r", label = "recent files",   hint = "r",       action = pick("recent") },
  -- SKELETON: no session plugin installed yet (handoff suggests folke/persistence.nvim)
  {
    key = "s",
    label = "restore session",
    hint = "s",
    action = stub("session restore is a stub — install folke/persistence.nvim")
  },
  {
    key = "p",
    label = "browse projects",
    hint = "p",
    action = pick("projects")
  },
  {
    key = "g",
    label = "lazygit",
    hint = "g",
    action = function()
      if vim.fn.executable("lazygit") == 1 then
        Snacks.lazygit()
      else
        stub("lazygit binary not found — brew install lazygit")()
      end
    end
  },
  {
    key = "c",
    label = "config",
    hint = "c",
    action = pick("files", { cwd = vim.fn.stdpath("config") })
  },
  { key = "L", label = "lazy", hint = "SPC L", action = ":Lazy" },
  { key = "q", label = "quit", hint = "q",     action = ":qa" },
}

-- ---------------------------------------------------------------------------
-- Left pane: RECENT files (dimmed dir + filename, dot leader, age right).
-- ---------------------------------------------------------------------------

local function recent_items()
  local items = {}
  for _, file in ipairs(vim.v.oldfiles or {}) do
    if #items >= M.opts.recent_limit then
      break
    end
    local stat = (file:sub(1, 1) == "/" and not file:find("COMMIT_EDITMSG", 1, true))
        and vim.uv.fs_stat(file)
        or nil
    if stat then
      local age = rel_age(stat.mtime.sec)
      -- prefer cwd-relative (":."), fall back to ~-relative, then pathshorten
      local name = vim.fn.fnamemodify(file, ":~:.")
      local budget = M.opts.width - strw(age) - 4
      if strw(name) > budget then
        name = vim.fn.pathshorten(vim.fn.fnamemodify(file, ":~"))
      end
      local dir, fname = name:match("^(.*/)(.+)$")
      dir, fname = dir or "", fname or name
      fname = truncate(fname, budget - strw(dir))
      items[#items + 1] = {
        action = function()
          vim.cmd("edit " .. vim.fn.fnameescape(file))
        end,
        text = row(
          { { dir, hl = "DashMuted" }, { fname, hl = "DashHeader" } },
          { { age, hl = "DashMuted" } }
        ),
      }
    end
  end
  if #items == 0 then
    items[1] = { text = { { "no recent files", hl = "DashMuted" } } }
  end
  return items
end

-- ---------------------------------------------------------------------------
-- Modules. Each renderer returns a list of snacks items (title row + content
-- lines). sections() stacks the enabled ones into pane 2.
-- ---------------------------------------------------------------------------

local modules = {}

-- STATUS — git / sys / obs / wx summary rows -------------------------------

local function labeled(label, segs)
  local t = { { label, hl = "DashMuted", width = 5 } }
  vim.list_extend(t, segs or pending())
  return t
end

local function git_status_line()
  return shell("status.git", 60, { "git", "status", "--porcelain=v2", "--branch" }, function(out)
    if not out then
      return { { "not a git repo", hl = "DashMuted" } }
    end
    local branch, ahead, behind, modified, untracked = "?", 0, 0, 0, 0
    for line in out:gmatch("[^\n]+") do
      local head = line:match("^# branch%.head (.+)")
      if head then
        branch = head
      end
      local a, b = line:match("^# branch%.ab %+(%d+) %-(%d+)")
      if a then
        ahead, behind = tonumber(a), tonumber(b)
      end
      local c = line:sub(1, 1)
      if c == "1" or c == "2" or c == "u" then
        modified = modified + 1
      elseif c == "?" then
        untracked = untracked + 1
      end
    end
    local t = { { branch, hl = "DashText" } }
    if ahead > 0 then
      t[#t + 1] = { " ↑" .. ahead, hl = "DashAccent" }
    end
    if behind > 0 then
      t[#t + 1] = { " ↓" .. behind, hl = "DashWarn" }
    end
    local counts = {}
    if modified > 0 then
      counts[#counts + 1] = modified .. " modified"
    end
    if untracked > 0 then
      counts[#counts + 1] = untracked .. " untracked"
    end
    if #counts > 0 then
      t[#t + 1] = { " · " .. table.concat(counts, ", "), hl = "DashGitMod" }
    else
      t[#t + 1] = { " · clean", hl = "DashMuted" }
    end
    return t
  end)
end

-- macOS-specific: ps/vm_stat/pmset. Cheap enough to run per dashboard open.
local sys_script = table.concat({
  [[cpu=$(ps -A -o %cpu | awk -v n="$(sysctl -n hw.ncpu)" '{s+=$1} END {printf "%.0f", s/n}')]],
  [[mem=$(vm_stat | awk -v ps="$(pagesize)" '/Pages (active|wired down|occupied by compressor)/ {gsub(/\./,"",$NF); s+=$NF} END {printf "%.1fG", s*ps/1073741824}')]],
  [[bat=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)]],
  [[printf 'cpu %s%% · mem %s · bat %s' "$cpu" "$mem" "${bat:-—}"]],
}, "; ")

local function sys_line()
  return shell("status.sys", 60, { "sh", "-c", sys_script }, function(out)
    return out and { { vim.trim(out), hl = "DashText" } } or { { "—", hl = "DashMuted" } }
  end)
end

-- SKELETON until M.opts.daily_note is configured (see OPTS above).
local function obs_line()
  local path = M.opts.daily_note and M.opts.daily_note() or nil
  if not path or vim.fn.filereadable(path) == 0 then
    return { { "no daily note", hl = "DashMuted" } }
  end
  local open = 0
  for _, line in ipairs(vim.fn.readfile(path)) do
    if line:match("^%s*[-*] %[ %]") then
      open = open + 1
    end
  end
  return {
    { tostring(open),                                       hl = "DashAccent" },
    { " open todos · " .. vim.fn.fnamemodify(path, ":t:r"), hl = "DashText" },
  }
end

local function weather_line()
  return async("status.wx", M.opts.weather_ttl, function(done)
    done = vim.schedule_wrap(done)
    local cache = vim.fn.stdpath("cache") .. "/dash-weather.txt"
    local stat = vim.uv.fs_stat(cache)
    if stat and os.time() - stat.mtime.sec < M.opts.weather_ttl then
      local f = io.open(cache, "r")
      if f then
        local s = f:read("*l")
        f:close()
        if s and s ~= "" then
          return done({ { s, hl = "DashText" } })
        end
      end
    end
    -- schedule_wrap: the callback uses nvim_strwidth (via truncate), which is
    -- not allowed in vim.system's fast event context
    vim.system({ "curl", "-sf", "-m", "5", "wttr.in/?format=%C+%t+·+%l" }, { text = true },
      vim.schedule_wrap(function(out)
        local s = out.code == 0 and vim.trim(out.stdout or "") or ""
        if s == "" or s:find("nknown") then
          return done({ { "—", hl = "DashMuted" } })
        end
        s = s:lower():gsub("%+", ""):gsub("%s+", " ")
        s = truncate(s, M.opts.width - 5) -- room for the STATUS row label
        local f = io.open(cache, "w")
        if f then
          f:write(s)
          f:close()
        end
        done({ { s, hl = "DashText" } })
      end))
  end)
end

function modules.status()
  return {
    title("STATUS", nil),
    { text = labeled("git", git_status_line()) },
    { text = labeled("sys", sys_line()) },
    { text = labeled("obs", obs_line()) },
    { text = labeled("wx", weather_line()) },
  }
end

-- MUSIC — Spotify via AppleScript (no playerctl on macOS) -------------------

local music_script = [[
if application "Spotify" is running then
  tell application "Spotify"
    set s to (player state as text)
    set t to name of current track
    set a to artist of current track
    return s & "\n" & t & "\n" & a
  end tell
end if
]]

local music_off = { { "♪ ", hl = "DashAccent" }, { "nothing playing", hl = "DashMuted" } }

local function music_line()
  return shell("music", 60, { "osascript", "-e", music_script }, function(out)
    if not out or vim.trim(out) == "" then
      music_playing = false
      return music_off
    end
    local parts = vim.split(out, "\n", { trimempty = true })
    if #parts < 3 then
      music_playing = false
      return music_off
    end
    music_playing = parts[1] == "playing"
    local artist = parts[3] or ""
    -- reserve the right edge for the visualizer overlay (VIZ_BARS wide)
    local budget = M.opts.width - 2 - strw(artist) - 2 - 12
    return {
      { "♪ ", hl = "DashAccent" },
      { truncate(parts[2] or "?", budget), hl = "DashText" },
      { "  " .. artist, hl = "DashMuted" },
    }
  end)
end

function modules.music()
  return {
    title("MUSIC", nil),
    { text = music_line() or pending() },
  }
end

-- GITHUB — PR/issue counts + contribution heatmap/stats via gh -------------

local gh_script = table.concat({
  [[prs=$(gh api 'search/issues?q=is:open+is:pr+review-requested:@me' --jq .total_count 2>/dev/null || echo '?')]],
  [[issues=$(gh api 'search/issues?q=is:open+is:issue+assignee:@me' --jq .total_count 2>/dev/null || echo '?')]],
  [[printf '%s\t%s' "$prs" "$issues"]],
}, "; ")

local github_contrib_query = [[
query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks {
          contributionDays {
            contributionCount
            date
            weekday
          }
        }
      }
    }
  }
}
]]

local function github_counts_line()
  return shell("github.counts", M.opts.github_ttl, { "sh", "-c", gh_script }, function(out)
    if not out then
      return { { "—", hl = "DashMuted" } }
    end
    local prs, issues = out:match("^(.-)\t(.*)$")
    return {
      { prs or "?",          hl = "DashAccent" },
      { " PRs to review   ", hl = "DashText" },
      { issues or "?",       hl = "DashAccent" },
      { " issues assigned",  hl = "DashText" },
    }
  end)
end

local github_weekday_labels = { "sun", "mon", "tue", "wed", "thu", "fri", "sat" }

local function github_display_weeks()
  -- label is "sun  "; cells are "■ " except the final "■". Fill the whole pane.
  local label_width = strw(github_weekday_labels[1] .. "  ")
  return math.max(1, math.floor((M.opts.width - label_width + 1) / 2))
end

local function heat_level(count)
  count = tonumber(count) or 0
  if count == 0 then
    return 0
  elseif count < 2 then
    return 1
  elseif count < 4 then
    return 2
  elseif count < 7 then
    return 3
  end
  return 4
end

local function github_contrib_lines()
  return shell("github.contrib", M.opts.github_ttl, {
    "gh",
    "api",
    "graphql",
    "-f",
    "login=" .. M.opts.github_login,
    "-f",
    "query=" .. github_contrib_query,
  }, function(out)
    if not out then
      return nil
    end
    local ok, decoded = pcall(vim.json.decode, out)
    local calendar = ok
        and decoded
        and decoded.data
        and decoded.data.user
        and decoded.data.user.contributionsCollection
        and decoded.data.user.contributionsCollection.contributionCalendar
        or nil
    if not calendar or not calendar.weeks then
      return nil
    end

    local all_days = {}
    local weeks = calendar.weeks
    local display_weeks = github_display_weeks()
    local data_weeks = math.min(M.opts.github_weeks, display_weeks, #weeks)
    local start = math.max(1, #weeks - data_weeks + 1)
    local grid = {}
    for weekday = 0, 6 do
      grid[weekday] = {}
      for col = 1, display_weeks do
        grid[weekday][col] = 0
      end
    end

    for _, week in ipairs(weeks) do
      for _, day in ipairs(week.contributionDays or {}) do
        all_days[#all_days + 1] = day
      end
    end
    table.sort(all_days, function(a, b)
      return (a.date or "") < (b.date or "")
    end)

    local today = os.date("%Y-%m-%d")
    local today_count, streak = 0, 0
    for i = #all_days, 1, -1 do
      local day = all_days[i]
      if (day.date or "") <= today then
        if day.date == today then
          today_count = day.contributionCount or 0
        end
        if (day.contributionCount or 0) > 0 then
          streak = streak + 1
        else
          break
        end
      end
    end

    local trailing_total = 0
    local current_weekday, current_col
    local col = 0
    for i = start, #weeks do
      col = col + 1
      for _, day in ipairs(weeks[i].contributionDays or {}) do
        local count = day.contributionCount or 0
        trailing_total = trailing_total + count
        grid[day.weekday or 0][col] = count
        if day.date == today then
          current_weekday = day.weekday or 0
          current_col = col
        end
      end
    end

    local lines = {
      {
        { tostring(calendar.totalContributions or 0), hl = "DashAccent" },
        { " total · ", hl = "DashMuted" },
        { tostring(trailing_total), hl = "DashAccent" },
        { "/" .. data_weeks .. "w · today ", hl = "DashMuted" },
        { tostring(today_count), hl = "DashAccent" },
        { " · streak ", hl = "DashMuted" },
        { streak > 0 and (streak .. "d") or "—", hl = streak > 0 and "DashAccent" or "DashMuted" },
      },
    }

    for weekday = 0, 6 do
      local row_segs = { { github_weekday_labels[weekday + 1] .. "  ", hl = "DashMuted" } }
      for col = 1, display_weeks do
        local level = heat_level(grid[weekday][col])
        local glyph = (weekday == current_weekday and col == current_col) and "◆" or "■"
        row_segs[#row_segs + 1] = { col < display_weeks and glyph .. " " or glyph, hl = "DashHeat" .. level }
      end
      lines[#lines + 1] = row_segs
    end

    return lines
  end)
end

function modules.github()
  local items = { title("GITHUB", { { "@" .. M.opts.github_login, hl = "DashMuted" } }) }
  if vim.fn.executable("gh") == 0 then
    items[#items + 1] = { text = { { "gh not installed · brew install gh", hl = "DashMuted" } } }
    return items
  end

  items[#items + 1] = { text = github_counts_line() or pending() }
  local contrib = github_contrib_lines()
  if contrib then
    for _, line in ipairs(contrib) do
      items[#items + 1] = { text = line }
    end
  else
    items[#items + 1] = { text = pending() }
    for weekday = 1, 7 do
      items[#items + 1] = {
        text = {
          { github_weekday_labels[weekday] .. "  ", hl = "DashMuted" },
          { string.rep("■ ", github_display_weeks() - 1) .. "■", hl = "DashHeat0" },
        },
      }
    end
  end
  return items
end

-- COMMITS — last 3, hash accent + subject + age right -----------------------

local function commit_lines()
  return shell("commits", 60, { "git", "log", "-3", "--pretty=%h\t%s\t%cr" }, function(out)
    if not out then
      return { { { "not a git repo", hl = "DashMuted" } } }
    end
    local lines = {}
    for line in out:gmatch("[^\n]+") do
      local hash, subject, age = line:match("^(%x+)\t(.-)\t(.*)$")
      if hash then
        age = short_age(age)
        local budget = M.opts.width - strw(hash) - 1 - strw(age) - 2
        lines[#lines + 1] = row(
          { { hash .. " ", hl = "DashAccent" }, { truncate(subject, budget), hl = "DashText" } },
          { { age, hl = "DashMuted" } },
          " "
        )
      end
    end
    return #lines > 0 and lines or { { { "no commits", hl = "DashMuted" } } }
  end)
end

function modules.commits()
  local items = { title("COMMITS", { { "git log", hl = "DashMuted" } }) }
  for _, line in ipairs(commit_lines() or { pending(), pending(), pending() }) do
    items[#items + 1] = { text = line }
  end
  return items
end

-- THEME — current colorscheme + its top accents as small squares, all on one
-- line; `t` opens a live colorscheme picker. (Not in the prototype: requested
-- addition. Swatches read the REAL highlight groups of the active theme, so
-- they stay correct after switching.)

local accent_groups = { "Function", "String", "Keyword", "Constant", "Special" }

local function swatches()
  local t = {}
  for _, group in ipairs(accent_groups) do
    local def = vim.api.nvim_get_hl(0, { name = group, link = false })
    if def.fg then
      vim.api.nvim_set_hl(0, "DashSwatch" .. group, { fg = def.fg })
      -- contiguous 2x1 blocks: each color two cells wide, touching the next
      t[#t + 1] = { "██", hl = "DashSwatch" .. group }
    end
  end
  return #t > 0 and t or { { "—", hl = "DashMuted" } }
end

local function theme_pick()
  Snacks.picker.colorschemes()
end

function modules.theme()
  local t = title("THEME", { { "[t]", hl = "DashKey" }, { " pick", hl = "DashMuted" } })
  t.key = "t" -- dashboard-local: t opens the colorscheme picker from anywhere
  t.action = theme_pick
  return {
    t,
    {
      text = row(
        { { vim.g.colors_name or "default", hl = "DashHeader" } },
        swatches(),
        " "
      ),
    },
  }
end

-- SYSTEM — cpu/mem/disk meters + battery (default off) ----------------------

local system_script = table.concat({
  [[cpu=$(ps -A -o %cpu | awk -v n="$(sysctl -n hw.ncpu)" '{s+=$1} END {printf "%.0f", s/n}')]],
  [[mem=$(vm_stat | awk -v ps="$(pagesize)" '/Pages (active|wired down|occupied by compressor)/ {gsub(/\./,"",$NF); s+=$NF} END {printf "%.1f", s*ps/1073741824}')]],
  [[memtot=$(($(sysctl -n hw.memsize) / 1073741824))]],
  [[disk=$(df -h / | awk 'NR==2 {gsub("%","",$5); print $5"\t"$3"/"$2}')]],
  [[bat=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%')]],
  [[printf '%s\t%s\t%s\t%s\t%s' "$cpu" "$mem" "$memtot" "$disk" "$bat"]],
}, "; ")

local function meter(pct, w)
  pct = math.max(0, math.min(100, pct))
  local fill = math.floor(pct / 100 * w + 0.5)
  return { string.rep("▰", fill) .. string.rep("▱", w - fill), pct }
end

local function system_lines()
  return shell("system", 60, { "sh", "-c", system_script }, function(out)
    if not out then
      return nil
    end
    local p = vim.split(out, "\t")
    local cpu, mem, memtot = tonumber(p[1]) or 0, tonumber(p[2]) or 0, tonumber(p[3]) or 1
    local diskpct, disktxt, bat = tonumber(p[4]) or 0, p[5] or "?", tonumber(p[6]) or 0
    local function meter_row(label, pct, txt)
      local bar = meter(pct, 14)[1]
      return row(
        { { label, hl = "DashMuted", width = 5 }, { bar, hl = "DashAccent" } },
        { { txt, hl = "DashText" } },
        " "
      )
    end
    return {
      meter_row("cpu", cpu, cpu .. "%"),
      meter_row("mem", mem / memtot * 100, ("%.1f/%dG"):format(mem, memtot)),
      meter_row("disk", diskpct, disktxt),
      meter_row("bat", bat, bat .. "%"),
    }
  end)
end

function modules.system()
  local items = { title("SYSTEM", { { vim.uv.os_gethostname():lower(), hl = "DashMuted" } }) }
  for _, line in ipairs(system_lines() or { pending(), pending(), pending(), pending() }) do
    items[#items + 1] = { text = line }
  end
  return items
end

-- TODOS — checklist from today's daily note (default off; SKELETON until
-- M.opts.daily_note is configured) ------------------------------------------

function modules.todos()
  local items = { title("TODOS", { { vim.fn.fnamemodify(M.opts.vault, ":t"), hl = "DashMuted" } }) }
  local path = M.opts.daily_note and M.opts.daily_note() or nil
  if not path or vim.fn.filereadable(path) == 0 then
    items[#items + 1] = { text = { { "no daily note today", hl = "DashMuted" } } }
    return items
  end
  local shown = 0
  for _, line in ipairs(vim.fn.readfile(path)) do
    local mark, body = line:match("^%s*[-*] %[(.)%] (.+)")
    if mark and shown < 6 then
      shown = shown + 1
      local done = mark ~= " "
      items[#items + 1] = {
        text = {
          { done and "✓ " or "· ", hl = done and "DashDone" or "DashDots" },
          { truncate(body, M.opts.width - 2), hl = done and "DashMuted" or "DashHeader" },
        },
      }
    end
  end
  if shown == 0 then
    items[#items + 1] = { text = { { "no todos today", hl = "DashMuted" } } }
  end
  return items
end

-- LAZY.NVIM — plugin count + updates + startup time (default off; the footer
-- already shows count/time). Update count works: checker.enabled = true in
-- config/lazy.lua.

function modules.lazy()
  local ok, lazy_stats = pcall(require, "lazy.stats")
  local line
  if ok then
    local s = lazy_stats.stats()
    line = {
      { tostring(s.count), hl = "DashAccent" },
      { " plugins · ", hl = "DashText" },
      { tostring(s.loaded), hl = "DashAccent" },
      { " loaded · λ ", hl = "DashText" },
      { ("%.1fms"):format(s.startuptime), hl = "DashAccent" },
    }
    local sok, lstatus = pcall(require, "lazy.status")
    local n = sok and lstatus.has_updates() and lstatus.updates():match("%d+") or nil
    if n then
      line[#line + 1] = { " · " .. n .. " updates", hl = "DashWarn" }
    end
  else
    line = { { "lazy.nvim not found", hl = "DashMuted" } }
  end
  return { title("LAZY.NVIM", { { "startup", hl = "DashMuted" } }), { text = line } }
end

-- ---------------------------------------------------------------------------
-- Tip of the day — one `:h` topic per day, sourced from nvim's own runtime
-- docs to nudge real config learning. Pool = every option (with its one-line
-- summary from quickref.txt's *option-list*) + every nvim_*/vim.* tag from
-- the doc tag index (api, lua, lsp, diagnostic, treesitter, ...). The pick is
-- deterministic per day: same tip all day, a scattered new one tomorrow.
-- ---------------------------------------------------------------------------

local tip_pool ---@type {tag:string, desc?:string, file?:string}[]?

local function build_tip_pool()
  local pool = {}
  -- options: quickref.txt carries a one-line summary per option
  local quickref = vim.env.VIMRUNTIME .. "/doc/quickref.txt"
  local in_list = false
  for _, line in ipairs(vim.fn.filereadable(quickref) == 1 and vim.fn.readfile(quickref) or {}) do
    if line:find("*option-list*", 1, true) then
      in_list = true
    elseif in_list and line:match("^%-%-%-%-") then
      break
    elseif in_list then
      local tag, desc = line:match("^'(%S+)'%s+(.+)$")
      if tag then
        desc = desc:gsub("^'%S+'%s*", "") -- drop the short-alias column
        pool[#pool + 1] = { tag = "'" .. tag .. "'", desc = desc }
      end
    end
  end
  -- api / lua / lsp: every nvim_*/vim.* tag in the runtime doc index
  local tags = vim.env.VIMRUNTIME .. "/doc/tags"
  for _, line in ipairs(vim.fn.filereadable(tags) == 1 and vim.fn.readfile(tags) or {}) do
    local tag, file = line:match("^(%S+)\t(%S+)\t")
    if tag and (tag:match("^nvim_%w") or tag:match("^vim%.%w")) then
      pool[#pool + 1] = { tag = tag, file = file }
    end
  end
  return pool
end

-- For doc-index tips, the description is the first prose line after the tag's
-- *anchor* in its help file. Resolved lazily for the day's pick only.
local function doc_desc(tip)
  if tip.desc or not tip.file then
    return
  end
  tip.desc = ""
  local path = vim.env.VIMRUNTIME .. "/doc/" .. tip.file
  local anchor = "*" .. tip.tag .. "*"
  local found = false
  for _, line in ipairs(vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}) do
    if found then
      local text = vim.trim((line:gsub("%*%S-%*", ""):gsub("[<>]", " ")))
      if text ~= "" and not text:match("^[%-=～]+$") then
        tip.desc = text
        return
      end
    elseif line:find(anchor, 1, true) then
      found = true
    end
  end
end

local function tip_of_the_day()
  tip_pool = tip_pool or build_tip_pool()
  if #tip_pool == 0 then
    return { tag = "lua-guide", desc = "getting started with Lua in Neovim" }
  end
  -- multiplicative hash so consecutive days don't pick adjacent pool entries
  local day = tonumber(os.date("%Y")) * 366 + tonumber(os.date("%j"))
  local tip = tip_pool[(day * 48271 % 2147483647) % #tip_pool + 1]
  doc_desc(tip)
  return tip
end

-- ---------------------------------------------------------------------------
-- sections() — assembles the two panes. Called by snacks every (re)render.
-- ---------------------------------------------------------------------------

function M.sections(dash)
  set_hl()

  -- Responsive pane width. snacks passes the dashboard instance here, and this
  -- runs during update()'s resolve() step — BEFORE snacks' own layout()/render()
  -- read dash.opts.width. So we shrink both widths in lockstep: M.opts.width
  -- drives the row()/budget math below; dash.opts.width drives snacks' pane
  -- placement and centering. Clamp to [40, max]; below ~2*40+gap snacks collapses
  -- to a single stacked pane on its own (and draw_divider bails). dash._size.width
  -- is the window width snacks centers on. See the "keep in sync" note in
  -- snacks.lua. (FRAGILE: relies on snacks calling sections(self) and resolve
  -- running before layout — revisit if a snacks update reorders update().)
  local narrow = false
  if dash and dash._size and dash.opts then
    local gap = dash.opts.pane_gap or 6
    local target = math.max(40, math.min(M.opts.width_max, math.floor((dash._size.width - gap) / 2)))
    M.opts.width = target
    dash.opts.width = target
    -- single-column (stacked) once two panes + gap no longer fit; mirrors
    -- snacks' own max_panes math in D:layout()
    narrow = math.floor((dash._size.width + gap) / (target + gap)) < 2
  end

  local width = M.opts.width
  local items = {}
  -- Track each pane's height (1 text line per item + padding) so the footer
  -- rows can be bottom-aligned across both panes.
  local heights = { 0, 0 }
  local function add(item, pane)
    item.pane = pane
    local pad = item.padding or 0
    pad = type(pad) == "table" and (pad[1] + pad[2]) or pad
    heights[pane] = heights[pane] + 1 + pad
    items[#items + 1] = item
    return item
  end

  -- In single-column mode the stacked content overflows and snacks can't center
  -- it, so it pins to row 1. Push it down a little so it doesn't hug the top.
  -- (No-op in two-pane mode, where snacks centers normally.)
  if narrow and M.opts.narrow_top_pad > 0 then
    add({ text = { { " " } }, padding = M.opts.narrow_top_pad - 1 }, 1)
  end

  -- pane 1 header: user@nvim + version, then the rule
  -- Alteration: a Good morning, afternoon, evening / greeting thing for my name and just the nvim and version
  local v = vim.version()
  add({
    text = {
      { (vim.env.USER or "user") .. "@nvim",               hl = "DashTop" },
      { ("  v%d.%d.%d"):format(v.major, v.minor, v.patch), hl = "DashTopMuted" },
    },
  }, 1)
  add({ text = { { string.rep("─", width), hl = "DashRule" } }, padding = 1 }, 1)

  -- pane 2 header: date · clock right-aligned, rule continues across the gap
  local clock = os.date("%I:%M%p"):lower():gsub("^0", "")
  add({
    text = row({}, {
      { os.date("%a %b %d"):lower() .. " · " .. clock, hl = "DashTopMuted" },
    }, " "),
  }, 2)
  add({ text = { { string.rep("─", width), hl = "DashRule" } }, padding = 1 }, 2)

  -- JUMP
  add(title("JUMP", nil), 1)
  for i, a in ipairs(jump_actions) do
    add({
      key = a.key,
      action = a.action,
      text = row(
        { { a.key, hl = "DashAccent" }, { "  " }, { a.label, hl = "DashText" } },
        { { a.hint, hl = "DashKey" } }
      ),
      padding = i < #jump_actions and M.opts.gap or 2,
    }, 1)
  end

  -- RECENT
  add(title("RECENT", { { "edited", hl = "DashMuted" } }), 1)
  local recents = recent_items()
  for i, item in ipairs(recents) do
    item.padding = i < #recents and M.opts.gap or 2
    add(item, 1)
  end

  -- pane 2: the module stack
  for _, mod in ipairs(M.opts.modules) do
    local id, enabled = mod[1], mod[2]
    if enabled and modules[id] then
      local mod_items = modules[id]()
      mod_items[#mod_items].padding = 2 -- module separation
      for _, item in ipairs(mod_items) do
        add(item, 2)
      end
    end
  end

  -- balance pane heights so both footer rows land on the same line
  local diff = heights[1] - heights[2]
  if diff > 0 then
    add({ text = { { " " } }, padding = diff - 1 }, 2)
  elseif diff < 0 then
    add({ text = { { " " } }, padding = -diff - 1 }, 1)
  end

  -- pane 1 footer: tip of the day — `h: <topic>` from nvim's own docs; `h` opens it
  local tip = tip_of_the_day()
  local desc = truncate(tip.desc or "", width - strw(tip.tag) - 4)
  add({
    key = "h",
    -- :help opens as a split; :only promotes it to the whole window (the
    -- dashboard buffer is bufhidden=wipe, so it cleans itself up)
    action = function()
      vim.cmd("help " .. tip.tag)
      vim.cmd("only")
    end,
    text = {
      { "h: ",                            hl = "DashKey" },
      { tip.tag,                          hl = "DashAccent" },
      { desc ~= "" and " " .. desc or "", hl = "DashMuted" },
    },
  }, 1)

  -- pane 2 footer: plugin count + startup time, right-aligned
  local ok, lazy_stats = pcall(require, "lazy.stats")
  if ok then
    local s = lazy_stats.stats()
    add({
      text = row({}, {
        { ("%d plugins · λ %.1fms"):format(s.count, s.startuptime), hl = "DashMuted" },
      }, " "),
    }, 2)
  end

  return items
end

-- ---------------------------------------------------------------------------
-- Vertical pane divider — the design's thin `│` rule down the middle. Drawn
-- as extmark virt_text OVERLAYS (window-column positioned), which never touch
-- buffer text, so snacks' own highlight extmarks survive.
-- ---------------------------------------------------------------------------

local divider_ns = vim.api.nvim_create_namespace("dash_ledger_divider")

local function dashboard_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "snacks_dashboard" then
      return buf
    end
  end
end

local function draw_divider()
  local buf = dashboard_buf()
  if not buf then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, divider_ns, 0, -1)
  local win = vim.fn.win_findbuf(buf)[1]
  if not win then
    return
  end
  -- The divider only makes sense in the side-by-side two-pane layout. Below the
  -- content-block width snacks stacks the panes vertically, and a fixed
  -- mid-column line would slice straight through that stacked content — so bail
  -- (the clear above already removed any stale divider from a wider render).
  local content_w = M.opts.width * 2 + 6 -- keep in sync with pane_gap in snacks.lua
  if vim.api.nvim_win_get_width(win) < content_w then
    return
  end
  -- anchor on CONTENT, not buffer rows: the buffer may carry blank centering
  -- rows above the header depending on window height
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local rule_row, footer_row
  for i, l in ipairs(lines) do
    if not rule_row and l:find("──", 1, true) then
      rule_row = i
    end
    if l:find("%S") then
      footer_row = i
    end
  end
  if not rule_row or not footer_row then
    return
  end
  -- center of the 6-col pane gap (content block is centered in the window)
  local col0 = math.max(0, math.floor((vim.api.nvim_win_get_width(win) - content_w) / 2))
  -- bridge the pane gap on the rule row, so the header rule reads as ONE line
  vim.api.nvim_buf_set_extmark(buf, divider_ns, rule_row - 1, 0, {
    virt_text = { { string.rep("─", 6), "DashRule" } },
    virt_text_win_col = col0 + M.opts.width,
  })
  -- vertical divider: from just below the rule to just above the footer
  local divider_col = col0 + M.opts.width + 3
  for lnum = rule_row + 2, footer_row - 2 do
    vim.api.nvim_buf_set_extmark(buf, divider_ns, lnum - 1, 0, {
      virt_text = { { "│", "DashRule" } },
      virt_text_win_col = divider_col,
    })
  end
end

-- ---------------------------------------------------------------------------
-- Editor chrome. While the dashboard is visible: hide gutter chrome in that
-- window only. Snacks applies its no-gutter window options before firing the
-- dashboard events, so restore the normal editing chrome when that window is
-- reused for a real file.
-- ---------------------------------------------------------------------------

local function dashboard_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
      return win
    end
  end
end

local saved_cmdheight ---@type number?
local dashboard_winopts = {
  "colorcolumn",
  "cursorcolumn",
  "cursorline",
  "foldcolumn",
  "foldmethod",
  "list",
  "number",
  "relativenumber",
  "sidescrolloff",
  "signcolumn",
  "spell",
  "statuscolumn",
  "statusline",
  "winbar",
  "winhighlight",
  "wrap",
}

-- Fallback for dashboards opened before this module had a chance to snapshot
-- the window (for example, a future startup-open path). User-invoked :Dashboard
-- goes through M.open() below, which restores the exact previous values.
local normal_winopts = {
  colorcolumn = "",
  cursorcolumn = false,
  cursorline = true,
  foldcolumn = "0",
  foldmethod = "manual",
  list = true,
  number = true,
  relativenumber = true,
  sidescrolloff = 0,
  signcolumn = "yes",
  spell = false,
  statuscolumn = "",
  statusline = "",
  winbar = "",
  winhighlight = "",
  wrap = false,
}
local dashboard_wins = {} ---@type table<integer, boolean>
local saved_winopts = {} ---@type table<integer, table<string, any>>
local scroll_locked = {} ---@type table<integer, boolean>

local function lock_mouse_scroll(buf)
  if scroll_locked[buf] then
    return
  end
  scroll_locked[buf] = true
  for _, key in ipairs({ "<ScrollWheelUp>", "<ScrollWheelDown>", "<ScrollWheelLeft>", "<ScrollWheelRight>" }) do
    vim.keymap.set({ "n", "i", "v", "x", "s", "o" }, key, "<Nop>", {
      buffer = buf,
      silent = true,
      nowait = true,
      desc = "Lock dashboard mouse scroll",
    })
  end
end

local function save_win_chrome(win)
  if not vim.api.nvim_win_is_valid(win) or saved_winopts[win] then
    return
  end

  local wo = vim.wo[win]
  saved_winopts[win] = {}
  for _, opt in ipairs(dashboard_winopts) do
    saved_winopts[win][opt] = wo[opt]
  end
end

local function mark_dashboard_win(win)
  if vim.api.nvim_win_is_valid(win) then
    dashboard_wins[win] = true
  end
end

local function restore_win_chrome(win)
  if not dashboard_wins[win] then
    return
  end

  if vim.api.nvim_win_is_valid(win) then
    local wo = vim.wo[win]
    for opt, value in pairs(saved_winopts[win] or normal_winopts) do
      wo[opt] = value
    end
  end
  dashboard_wins[win] = nil
  saved_winopts[win] = nil
end

local function restore_current_win_chrome_if_needed()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "snacks_dashboard" then
    restore_win_chrome(win)
  end
end

local function apply_chrome()
  -- no cmdline row while the dashboard is up — the DASH statusline should be
  -- the very bottom of the screen
  if vim.o.cmdheight ~= 0 then
    saved_cmdheight = vim.o.cmdheight
    vim.o.cmdheight = 0
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "snacks_dashboard" then
      lock_mouse_scroll(buf)
      mark_dashboard_win(win)
      local wo = vim.wo[win]
      wo.number = false
      wo.relativenumber = false
      wo.statuscolumn = ""
      wo.signcolumn = "no"
      wo.foldcolumn = "0"
    end
  end
end

local function restore_chrome()
  if saved_cmdheight then
    vim.o.cmdheight = saved_cmdheight
    saved_cmdheight = nil
  end

  for win in pairs(dashboard_wins) do
    restore_win_chrome(win)
  end
end

local function refresh_statusline()
  -- lualine's globalstatus mode owns this during normal startup, but the
  -- dashboard can render before the first statusline redraw. Force both the
  -- option and a redraw while the dashboard is visible.
  vim.o.laststatus = 3
  pcall(function()
    require("lualine").refresh({ place = { "statusline" } })
  end)
  vim.cmd.redrawstatus()
end

function M.open()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("snacks.nvim is not available", vim.log.levels.WARN)
    return
  end

  local win = vim.api.nvim_get_current_win()
  save_win_chrome(win)
  snacks.dashboard.open({ win = win })
end

-- Consumed by the lualine snacks_dashboard extension (statusline.lua): the
-- already-fetched weather string, or "" while it loads.
function M.weather_text()
  local j = jobs["status.wx"]
  local seg = j and j.result and j.result[1]
  return seg and seg[1] or ""
end

-- ---------------------------------------------------------------------------
-- MUSIC live updates — only while the dashboard is open; both timers start on
-- Opened and stop on Closed, so nothing runs while actually editing.
--
-- * poll timer: re-reads Spotify every music_poll seconds but ONLY re-renders
--   when the track/state actually changed — a full re-render every tick
--   visibly flickers, so position/length are a snapshot per song.
-- * viz timer: a small animated equalizer, drawn as an extmark overlay on the
--   ♪ line (extmark updates never rewrite buffer text → no flicker). There is
--   no real audio-level source here; it's a smoothed random walk that runs
--   while the player state is "playing".
-- ---------------------------------------------------------------------------

local music_timer ---@type uv.uv_timer_t?
local music_sig ---@type string? last seen "state\ntitle\nartist" fingerprint
local viz_timer ---@type uv.uv_timer_t?
local viz_ns = vim.api.nvim_create_namespace("dash_ledger_viz")
local viz_heights = {} ---@type number[]
local VIZ_BARS = 10
local VIZ_CHARS = { "▁", "▂", "▃", "▄", "▅", "▆", "▇" }

local function music_enabled()
  for _, mod in ipairs(M.opts.modules) do
    if mod[1] == "music" then
      return mod[2]
    end
  end
  return false
end

local function poll_music()
  if not dashboard_win() then
    return
  end
  pcall(vim.system, { "osascript", "-e", music_script }, { text = true }, vim.schedule_wrap(function(out)
    local raw = out.code == 0 and vim.trim(out.stdout or "") or ""
    -- fingerprint = state + title + artist; position changes every tick and
    -- must NOT count as a change
    local sig = raw:match("^([^\n]*\n[^\n]*\n[^\n]*)") or raw
    local changed = music_sig ~= nil and sig ~= music_sig
    music_sig = sig
    music_playing = sig:match("^playing") ~= nil
    if changed then
      jobs.music = nil -- expire the cache so the re-render refetches
      pcall(function()
        Snacks.dashboard.update()
      end)
    end
  end))
end

local function draw_viz()
  local buf = dashboard_buf()
  if not buf then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, viz_ns, 0, -1)
  if not music_playing then
    return
  end
  local win = vim.fn.win_findbuf(buf)[1]
  if not win then
    return
  end
  -- Same fixed-column assumption as the divider: skip in the narrow/stacked
  -- layout so the equalizer is not overlaid at a meaningless screen column.
  local content_w = M.opts.width * 2 + 6
  if vim.api.nvim_win_get_width(win) < content_w then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local row
  for i, l in ipairs(lines) do
    if l:find("♪", 1, true) then
      row = i
      break
    end
  end
  if not row then
    return
  end
  -- each bar random-walks one step toward a fresh target — smoother than
  -- pure noise, cheap enough to run every tick
  local bars = {}
  for i = 1, VIZ_BARS do
    local h = viz_heights[i] or math.random(#VIZ_CHARS)
    local target = math.random(#VIZ_CHARS)
    h = h + (target > h and 1 or target < h and -1 or 0)
    viz_heights[i] = h
    bars[i] = VIZ_CHARS[h]
  end
  -- right-aligned at the end of pane 2, on the ♪ line
  local content_w = M.opts.width * 2 + 6
  local col0 = math.max(0, math.floor((vim.api.nvim_win_get_width(win) - content_w) / 2))
  vim.api.nvim_buf_set_extmark(buf, viz_ns, row - 1, 0, {
    virt_text = { { table.concat(bars), "DashAccent" } },
    virt_text_win_col = col0 + content_w - VIZ_BARS,
  })
end

local function start_music_poll()
  if music_timer or not music_enabled() then
    return
  end
  local ms = M.opts.music_poll * 1000
  music_timer = vim.uv.new_timer()
  music_timer:start(ms, ms, vim.schedule_wrap(poll_music))
  viz_timer = vim.uv.new_timer()
  viz_timer:start(400, 180, vim.schedule_wrap(function()
    pcall(draw_viz)
  end))
end

local function stop_music_poll()
  for _, timer in ipairs({ music_timer, viz_timer }) do
    if timer then
      timer:stop()
      timer:close()
    end
  end
  music_timer, viz_timer = nil, nil
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("DashLedger", { clear = true })

-- Colorscheme switch (incl. every THEME-picker preview step): re-render so
-- Dash* groups and swatches rebuild against the new theme.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    pcall(function()
      Snacks.dashboard.update()
    end)
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "SnacksDashboardUpdatePost",
  callback = function()
    -- Drop snacks' ongoing cursor-snap. It re-pins the cursor onto an
    -- actionable row on every CursorMoved; once you scroll down to a pane whose
    -- only action is far away (e.g. pane 2's lone THEME [t]), D:find can only
    -- return that one item, so <C-u> moves up and the snap yanks it back —
    -- <C-u> appears dead while <C-d> works. The one-time snap from this same
    -- update() already placed the cursor on an action; we only remove the
    -- persistent handler so the dashboard scrolls freely. Single-key actions
    -- (f, /, t, ...) are unaffected — they're bound to keys, not cursor pos.
    -- snacks recreates the group each update(), so re-clear every UpdatePost.
    -- FRAGILE: depends on the snacks-internal augroup name.
    pcall(vim.api.nvim_clear_autocmds, { group = "snacks_dashboard_cursor" })
    pcall(draw_divider)
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "SnacksDashboardOpened",
  callback = function()
    apply_chrome()
    refresh_statusline()
    start_music_poll()
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "SnacksDashboardClosed",
  callback = function()
    stop_music_poll()
    restore_chrome()
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = group,
  desc = "Restore editor chrome after leaving the dashboard window",
  callback = restore_current_win_chrome_if_needed,
})

return M
