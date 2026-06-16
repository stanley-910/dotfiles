-- Project sessions: tiny native-session wrapper keyed by git root (or cwd)
-- and, for git repos, the current branch.
--
-- Docs anchors:
--   :help vim.fs.root()
--   :help :mksession
--   :help 'sessionoptions'
--   :help v:this_session
--   :help Snacks.picker.select()

local M = {}

local defaults = {
  dir = vim.fn.stdpath("state") .. "/sessions",
  branch = true,
  min_file_buffers = 1,
  notify = true,
  skip_nested = true,
  sessionoptions = {
    "buffers",
    "curdir",
    "folds",
    "help",
    "tabpages",
    "winsize",
    "terminal",
    "localoptions",
  },
  worktrees = {
    enabled = true,
    base_dir = vim.fn.expand("~/Developer/worktrees"),
  },
}

M.opts = vim.deepcopy(defaults)
M.active = false

local function notify(msg, level)
  if M.opts.notify then
    vim.notify(msg, level or vim.log.levels.INFO, { title = "sessions" })
  end
end

local function ensure_dir()
  vim.fn.mkdir(M.opts.dir, "p")
end

local function normalize(path)
  local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  return normalized == "/" and normalized or normalized:gsub("/$", "")
end

local function basename(path)
  local name = vim.fn.fnamemodify(path, ":t")
  return name ~= "" and name or path
end

local function current_root()
  local cwd = vim.fn.getcwd()
  return normalize(vim.fs.root(cwd, ".git") or cwd)
end

local function run(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  local out = vim.trim(result.stdout or "")
  return out ~= "" and out or nil
end

local function current_branch(root)
  if vim.fn.isdirectory(root .. "/.git") == 0 and vim.fn.filereadable(root .. "/.git") == 0 then
    return nil
  end

  return run({ "git", "-C", root, "branch", "--show-current" })
      or (function()
        local head = run({ "git", "-C", root, "rev-parse", "--short", "HEAD" })
        return head and ("detached-" .. head) or nil
      end)()
end

local function git_status(root)
  local result = vim.system({ "git", "-C", root, "status", "--porcelain" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or result.stdout or "git status failed")
  end
  return vim.trim(result.stdout or "")
end

local function git_switch(root, branch)
  local result = vim.system({ "git", "-C", root, "switch", branch }, { text = true }):wait()
  if result.code == 0 then
    return true
  end
  return false, vim.trim(result.stderr or result.stdout or "git switch failed")
end

local function list_worktrees(root)
  local result = vim.system({ "git", "-C", root, "worktree", "list", "--porcelain" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or result.stdout or "git worktree list failed")
  end

  local trees = {}
  local tree = nil
  for line in (result.stdout or ""):gmatch("[^\n]+") do
    local path = line:match("^worktree (.+)$")
    if path then
      if tree and tree.path then
        trees[#trees + 1] = tree
      end
      tree = { path = normalize(path) }
    elseif tree then
      local branch = line:match("^branch refs/heads/(.+)$")
      if branch then
        tree.branch = branch
      end
    end
  end

  if tree and tree.path then
    trees[#trees + 1] = tree
  end

  return trees
end

local function worktree_for_branch(root, branch)
  local trees, err = list_worktrees(root)
  if not trees then
    return nil, err
  end

  for _, tree in ipairs(trees) do
    if tree.branch == branch and vim.fn.isdirectory(tree.path) == 1 then
      return tree.path
    end
  end
end

local function worktree_path(root, branch)
  local parent = M.opts.worktrees.base_dir and vim.fn.expand(M.opts.worktrees.base_dir) or vim.fn.fnamemodify(root, ":h")
  local slug = branch:gsub("[^%w._-]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  return normalize(parent .. "/" .. basename(root) .. "-" .. slug)
end

local function git_worktree_add(root, path, branch)
  if vim.fn.isdirectory(path) == 1 or vim.fn.filereadable(path) == 1 then
    return false, "path already exists: " .. path
  end

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local result = vim.system({ "git", "-C", root, "worktree", "add", path, branch }, { text = true }):wait()
  if result.code == 0 then
    return true
  end
  return false, vim.trim(result.stderr or result.stdout or "git worktree add failed")
end

local function git_branch_exists(root, branch)
  if not branch or branch:find("^detached%-") then
    return true
  end

  local result = vim.system({ "git", "-C", root, "show-ref", "--verify", "--quiet", "refs/heads/" .. branch }):wait()
  return result.code == 0
end

local function delete_file(path)
  if path and path ~= "" and (vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1) then
    vim.fn.delete(path)
  end
end

local function session_context()
  local root = current_root()
  local branch = M.opts.branch and current_branch(root) or nil
  local key = branch and (root .. "::" .. branch) or root
  local id = vim.fn.sha256(key)

  return {
    version = 1,
    id = id,
    key = key,
    root = root,
    cwd = normalize(vim.fn.getcwd()),
    branch = branch,
    session = M.opts.dir .. "/" .. id .. ".vim",
    meta = M.opts.dir .. "/" .. id .. ".json",
  }
end

local function file_buffer_count()
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
      count = count + 1
    end
  end
  return count
end

local function modified_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then
      buffers[#buffers + 1] = buf
    end
  end
  return buffers
end

local function buffer_label(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" then
    return vim.fn.fnamemodify(name, ":~:.")
  end

  local buftype = vim.bo[buf].buftype
  return buftype ~= "" and ("[" .. buftype .. " buffer " .. buf .. "]") or ("[No Name " .. buf .. "]")
end

local function save_buffer(buf)
  return pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent write")
  end)
end

local function prompt_save_modified_buffers(done)
  local buffers = modified_buffers()
  local index = 1

  local function step()
    while index <= #buffers and not vim.bo[buffers[index]].modified do
      index = index + 1
    end

    local buf = buffers[index]
    if not buf then
      done(true)
      return
    end

    local label = buffer_label(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" or vim.bo[buf].buftype ~= "" then
      notify("Cannot auto-save modified scratch/special buffer " .. label, vim.log.levels.WARN)
      done(false)
      return
    end

    vim.ui.select({ "Save", "Cancel" }, {
      prompt = "Save modified buffer before switching sessions? " .. label,
    }, function(choice)
      if choice ~= "Save" then
        done(false)
        return
      end

      local ok, err = save_buffer(buf)
      if not ok then
        notify("Could not save " .. label .. ": " .. tostring(err), vim.log.levels.ERROR)
        done(false)
        return
      end

      index = index + 1
      step()
    end)
  end

  step()
end

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or vim.tbl_isempty(lines) then
    return nil
  end

  local decode_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok or type(data) ~= "table" then
    return nil
  end

  return data
end

local function write_json(path, data)
  vim.fn.writefile({ vim.json.encode(data) }, path)
end

local function stale_reason(item)
  if not item then
    return "invalid metadata"
  end
  if not item.session or vim.fn.filereadable(item.session) == 0 then
    return "missing session file"
  end
  if item.root and vim.fn.isdirectory(item.root) == 0 then
    return "missing root"
  end
  if item.root and item.branch and not git_branch_exists(item.root, item.branch) then
    return "missing git branch"
  end
end

local function short_age(updated)
  if type(updated) ~= "number" then
    return ""
  end

  local seconds = math.max(os.time() - updated, 0)
  if seconds < 60 then
    return "now"
  elseif seconds < 3600 then
    return math.floor(seconds / 60) .. "m"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h"
  elseif seconds < 7 * 86400 then
    return math.floor(seconds / 86400) .. "d"
  end
  return math.floor(seconds / (7 * 86400)) .. "w"
end

local function display(item)
  local name = item.name or basename(item.root or "")
  local branch = item.branch and (" " .. item.branch) or "cwd"
  local age = short_age(item.updated)
  return string.format("%-22s %-18s %-5s %s", name, branch, age, item.root or "")
end

local function label(item)
  local name = item.name or basename(item.root or "")
  return item.branch and (name .. " on '" .. item.branch .. "'") or name
end

function M.current()
  return session_context()
end

function M.save(opts)
  opts = opts or {}

  if opts.autosave and not M.active then
    return false
  end

  if M.opts.skip_nested and vim.env.NVIM then
    return false
  end

  if file_buffer_count() < M.opts.min_file_buffers then
    return false
  end

  ensure_dir()

  local ctx = session_context()
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(ctx.session))
  if not ok then
    if not opts.quiet then
      notify("Could not save session: " .. err, vim.log.levels.ERROR)
    end
    return false
  end

  ctx.name = basename(ctx.root)
  ctx.updated = os.time()
  write_json(ctx.meta, ctx)
  vim.v.this_session = ctx.session
  M.active = true

  if not opts.quiet then
    notify("Saved " .. label(ctx))
  end

  return true
end

function M.list()
  ensure_dir()

  local items = {}
  for _, meta in ipairs(vim.fn.glob(M.opts.dir .. "/*.json", true, true)) do
    local item = read_json(meta)
    if item and item.session and vim.fn.filereadable(item.session) == 1 then
      item.meta = meta
      items[#items + 1] = item
    end
  end

  table.sort(items, function(a, b)
    return (a.updated or 0) > (b.updated or 0)
  end)

  return items
end

local function stale_entries()
  ensure_dir()

  local stale = {}
  local seen_sessions = {}
  for _, meta in ipairs(vim.fn.glob(M.opts.dir .. "/*.json", true, true)) do
    local item = read_json(meta)
    if item and item.session then
      seen_sessions[normalize(item.session)] = true
    end

    local reason = stale_reason(item)
    if reason then
      stale[#stale + 1] = {
        meta = meta,
        session = item and item.session or nil,
        root = item and item.root or nil,
        branch = item and item.branch or nil,
        reason = reason,
      }
    end
  end

  for _, session in ipairs(vim.fn.glob(M.opts.dir .. "/*.vim", true, true)) do
    if not seen_sessions[normalize(session)] then
      stale[#stale + 1] = {
        session = session,
        reason = "missing metadata",
      }
    end
  end

  return stale
end

function M.prune(opts)
  opts = opts or {}
  local stale = stale_entries()
  if vim.tbl_isempty(stale) then
    if not opts.quiet then
      notify("No stale sessions to prune")
    end
    return 0
  end

  local function prune_now()
    for _, entry in ipairs(stale) do
      delete_file(entry.session)
      delete_file(entry.meta)
    end

    if not opts.quiet then
      notify("Pruned " .. #stale .. " stale session" .. (#stale == 1 and "" or "s"))
    end
    return #stale
  end

  if opts.confirm == false then
    return prune_now()
  end

  local preview = vim.tbl_map(function(entry)
    return entry.reason .. ": " .. (entry.root or entry.session or entry.meta or "unknown")
  end, stale)

  vim.ui.select({ "Prune", "Cancel" }, {
    prompt = "Prune " .. #stale .. " stale session" .. (#stale == 1 and "" or "s") .. "? " .. table.concat(preview, " | "),
  }, function(choice)
    if choice == "Prune" then
      prune_now()
    end
  end)

  return #stale
end

local function session_for_root_branch(root, branch)
  root = normalize(root)
  for _, item in ipairs(M.list()) do
    if item.root and normalize(item.root) == root and item.branch == branch then
      return item
    end
  end
end

local function open_root(root, branch)
  if root and root ~= "" then
    vim.cmd("cd " .. vim.fn.fnameescape(root))
  end

  pcall(vim.cmd, "silent! %bwipeout!")
  M.active = true
  notify("Opened " .. basename(root) .. " on '" .. branch .. "'; no saved session exists there yet")
  return true
end

local function worktree_target(path, branch)
  return session_for_root_branch(path, branch) or {
    root = path,
    branch = branch,
    name = basename(path),
    open_only = true,
  }
end

function M.load(item)
  if not item or not item.session or vim.fn.filereadable(item.session) == 0 then
    notify("Session file is missing", vim.log.levels.WARN)
    return false
  end

  if #modified_buffers() > 0 then
    notify("Unsaved buffers; refusing to restore a session", vim.log.levels.WARN)
    return false
  end

  if item.root and item.root ~= "" then
    vim.cmd("cd " .. vim.fn.fnameescape(item.root))
  end

  local ok, err = pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(item.session))
  if not ok then
    notify("Could not restore session: " .. err, vim.log.levels.ERROR)
    return false
  end

  vim.v.this_session = item.session
  M.active = true
  notify("Restored " .. label(item))
  return true
end

local function ensure_target_branch(item, done)
  if not item.root or not item.branch then
    done(item)
    return
  end

  local current = current_branch(item.root)
  if not current or current == item.branch then
    done(item)
    return
  end

  if item.branch:find("^detached%-") then
    notify("Session was saved from a detached HEAD; checkout the target manually first", vim.log.levels.WARN)
    done(false)
    return
  end

  local status, status_err = git_status(item.root)
  if status == nil then
    notify("Could not inspect git status: " .. status_err, vim.log.levels.ERROR)
    done(false)
    return
  end

  if status ~= "" then
    if not M.opts.worktrees.enabled then
      notify(
        "Refusing to switch from "
          .. current
          .. " to "
          .. item.branch
          .. " with uncommitted work. Commit, stash, or use a worktree.",
        vim.log.levels.WARN
      )
      done(false)
      return
    end

    local existing, err = worktree_for_branch(item.root, item.branch)
    if err then
      notify("Could not inspect git worktrees: " .. err, vim.log.levels.ERROR)
      done(false)
      return
    end

    if existing then
      vim.ui.select({ "Open worktree", "Cancel" }, {
        prompt = "Uncommitted work on " .. current .. ". Open existing " .. item.branch .. " worktree? " .. existing,
      }, function(choice)
        done(choice == "Open worktree" and worktree_target(existing, item.branch) or false)
      end)
      return
    end

    local path = worktree_path(item.root, item.branch)
    vim.ui.select({ "Create worktree", "Cancel" }, {
      prompt = "Uncommitted work on " .. current .. ". Create worktree for " .. item.branch .. " at " .. path .. "?",
    }, function(choice)
      if choice ~= "Create worktree" then
        done(false)
        return
      end

      local ok, add_err = git_worktree_add(item.root, path, item.branch)
      if not ok then
        notify("Could not create worktree: " .. add_err, vim.log.levels.ERROR)
        done(false)
        return
      end

      done(worktree_target(path, item.branch))
    end)
    return
  end

  vim.ui.select({ "Switch and load", "Cancel" }, {
    prompt = "Switch " .. basename(item.root) .. " from " .. current .. " to " .. item.branch .. "?",
  }, function(choice)
    if choice ~= "Switch and load" then
      done(false)
      return
    end

    local ok, err = git_switch(item.root, item.branch)
    if not ok then
      notify("Could not switch branch: " .. err, vim.log.levels.ERROR)
      done(false)
      return
    end

    done(item)
  end)
end

function M.switch(item)
  prompt_save_modified_buffers(function(saved)
    if not saved then
      notify("Session switch cancelled", vim.log.levels.WARN)
      return
    end

    if M.active then
      M.save({ quiet = true })
    end
    ensure_target_branch(item, function(target)
      if not target then
        return
      end

      if target.open_only then
        open_root(target.root, target.branch)
      else
        M.load(target)
      end
    end)
  end)
end

function M.load_current()
  local ctx = session_context()
  local item = read_json(ctx.meta) or ctx
  item.session = item.session or ctx.session
  item.root = item.root or ctx.root
  return M.load(item)
end

function M.select()
  local sessions = M.list()
  if vim.tbl_isempty(sessions) then
    notify("No saved sessions yet", vim.log.levels.WARN)
    return
  end

  if Snacks and Snacks.picker and Snacks.picker.pick then
    local items = vim.tbl_map(function(session)
      local item = vim.deepcopy(session)
      item.id = session.id or session.session
      item.session = session
      item.text = display(session)
      return item
    end, sessions)

    local function remove_items(selected)
      local remove = {}
      for _, item in ipairs(selected) do
        remove[item.id] = true
        delete_file(item.session.session)
        delete_file(item.session.meta)
      end

      for i = #items, 1, -1 do
        if remove[items[i].id] then
          table.remove(items, i)
        end
      end
    end

    Snacks.picker.pick({
      title = "Sessions",
      items = items,
      format = "text",
      layout = { preview = false },
      confirm = function(picker, item)
        picker:close()
        if item then
          M.switch(item.session)
        end
      end,
      actions = {
        delete_session = {
          desc = "Delete selected session",
          action = function(picker)
            local selected = picker:selected({ fallback = true })
            if vim.tbl_isempty(selected) then
              return
            end

            vim.ui.select({ "Delete", "Cancel" }, {
              prompt = "Delete " .. #selected .. " selected session" .. (#selected == 1 and "" or "s") .. "?",
            }, function(choice)
              if choice ~= "Delete" then
                return
              end

              remove_items(selected)
              notify("Deleted " .. #selected .. " session" .. (#selected == 1 and "" or "s"))
              if vim.tbl_isempty(items) then
                picker:close()
              else
                picker:refresh()
              end
            end)
          end,
        },
        prune_sessions = {
          desc = "Prune stale sessions",
          action = function(picker)
            local pruned = M.prune({ confirm = false })
            if pruned > 0 then
              picker:close()
              vim.schedule(M.select)
            else
              picker:refresh()
            end
          end,
        },
      },
      win = {
        input = {
          keys = {
            ["<C-d>"] = { "delete_session", mode = { "i", "n" } },
            ["<C-p>"] = { "prune_sessions", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["dd"] = "delete_session",
            ["p"] = "prune_sessions",
          },
        },
      },
    })
    return
  end

  vim.ui.select(sessions, {
    prompt = "Sessions",
    format_item = display,
  }, function(item)
    if item then
      M.switch(item)
    end
  end)
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  ensure_dir()
  vim.opt.sessionoptions = M.opts.sessionoptions

  local group = vim.api.nvim_create_augroup("ConfigSessions", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    desc = "Autosave project session",
    callback = function()
      require("config.sessions").save({ quiet = true, autosave = true })
    end,
  })

  vim.api.nvim_create_user_command("SessionSave", function()
    M.save()
  end, { desc = "Save current project session and enable autosave" })

  vim.api.nvim_create_user_command("SessionSelect", function()
    M.select()
  end, { desc = "Pick and restore a project session" })

  vim.api.nvim_create_user_command("SessionLoad", function()
    M.load_current()
  end, { desc = "Restore session for current project/branch" })

  vim.api.nvim_create_user_command("SessionStop", function()
    M.active = false
    notify("Session autosave stopped")
  end, { desc = "Disable session autosave for this Neovim instance" })

  vim.api.nvim_create_user_command("SessionPrune", function(args)
    M.prune({ confirm = not args.bang })
  end, { bang = true, desc = "Prune stale project sessions" })
end

return M
