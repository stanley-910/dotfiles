-- PROTOTYPE: action registry for config.quickbind.
--
-- This keeps generated keybinds stable by saving an action id, not raw Lua
-- source. If an action changes, update it here and every generated binding keeps
-- working. See :h vim.keymap.set() for why rhs can be either a string or function.

local M = {}

local function cmd(command)
  return "<cmd>" .. command .. "<CR>"
end

local function require_or_notify(module, plugin_name)
  local ok, mod = pcall(require, module)
  if ok then
    return mod
  end

  vim.notify((plugin_name or module) .. " is not installed yet", vim.log.levels.WARN)
  return nil
end

local function snacks_picker(picker, picker_opts)
  return function()
    local snacks = require_or_notify("snacks", "snacks.nvim")
    local pick = snacks and snacks.picker and snacks.picker[picker]
    if pick then
      pick(picker_opts or {})
    else
      vim.notify("Snacks picker '" .. picker .. "' is not available", vim.log.levels.WARN)
    end
  end
end

local function oil_open()
  local oil = require_or_notify("oil", "oil.nvim")
  if oil then
    oil.open()
  end
end

local function tiny_code_action()
  local tiny = require_or_notify("tiny-code-action", "tiny-code-action.nvim")
  if tiny then
    tiny.code_action()
  end
end

local function gitsigns(action)
  return function()
    local gs = require_or_notify("gitsigns", "gitsigns.nvim")
    if gs then
      gs[action]()
    end
  end
end

local function delete_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, buffer in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if buffer.bufnr ~= current then
      pcall(vim.api.nvim_buf_delete, buffer.bufnr, {})
    end
  end
end

local function close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, false)
    end
  end
end

local function diagnostic_jump(count)
  return function()
    vim.diagnostic.jump({ count = count })
  end
end

local function add(actions, action)
  action.mode = action.mode or "n"
  action.category = action.category or "misc"
  actions[#actions + 1] = action
end

local function add_curated_actions(actions)
  -- Quickbinder self-management ------------------------------------------------
  add(actions, { id = "quickbind.bind", desc = "Quick bind action", category = "keybinds", rhs = cmd("QuickBind") })
  add(actions, { id = "quickbind.list", desc = "List generated quickbinds", category = "keybinds", rhs = cmd("QuickBindList") })
  add(actions, { id = "quickbind.edit", desc = "Edit generated quickbinds", category = "keybinds", rhs = cmd("QuickBindEdit") })
  add(actions, { id = "quickbind.reload", desc = "Reload generated quickbinds", category = "keybinds", rhs = cmd("QuickBindReload") })
  add(actions, { id = "quickbind.delete", desc = "Delete generated quickbind", category = "keybinds", rhs = cmd("QuickBindDelete") })

  -- Files/search ----------------------------------------------------------------
  add(actions, { id = "file.find", desc = "Find files", category = "find", rhs = snacks_picker("files") })
  add(actions, { id = "file.oldfiles", desc = "Recent files", category = "find", rhs = snacks_picker("recent") })
  add(actions, { id = "file.buffers", desc = "Find buffers", category = "find", rhs = snacks_picker("buffers") })
  add(actions, { id = "file.grep", desc = "Find in project", category = "find", rhs = snacks_picker("grep") })
  add(actions, { id = "file.grep_word", desc = "Find word under cursor", category = "find", rhs = snacks_picker("grep_word") })
  add(actions, { id = "file.help", desc = "Find help tags", category = "find", rhs = snacks_picker("help") })
  add(actions, { id = "file.commands", desc = "Find commands", category = "find", rhs = snacks_picker("commands") })
  add(actions, { id = "file.keymaps", desc = "Find keymaps", category = "find", rhs = snacks_picker("keymaps") })
  add(actions, { id = "file.diagnostics", desc = "Find diagnostics", category = "find", rhs = snacks_picker("diagnostics") })
  add(actions, { id = "file.oil", desc = "Open parent directory in Oil", category = "files", rhs = oil_open })
  add(actions, { id = "file.write", desc = "Write buffer", category = "files", rhs = cmd("write") })
  add(actions, { id = "file.write_all", desc = "Write all buffers", category = "files", rhs = cmd("wall") })
  add(actions, { id = "file.source", desc = "Source current file", category = "files", rhs = cmd("source %") })

  -- Buffers/windows -------------------------------------------------------------
  add(actions, { id = "buffer.next", desc = "Next buffer", category = "buffers", rhs = cmd("bnext") })
  add(actions, { id = "buffer.prev", desc = "Previous buffer", category = "buffers", rhs = cmd("bprevious") })
  add(actions, { id = "buffer.delete", desc = "Delete buffer", category = "buffers", rhs = cmd("bdelete") })
  add(actions, { id = "buffer.only", desc = "Delete other buffers", category = "buffers", rhs = delete_other_buffers })
  add(actions, { id = "window.split", desc = "Split horizontally", category = "windows", rhs = cmd("split") })
  add(actions, { id = "window.vsplit", desc = "Split vertically", category = "windows", rhs = cmd("vsplit") })
  add(actions, { id = "window.close", desc = "Close window", category = "windows", rhs = cmd("close") })
  add(actions, { id = "window.only", desc = "Only window", category = "windows", rhs = cmd("only") })
  add(actions, { id = "window.equalize", desc = "Equalize windows", category = "windows", rhs = "<C-w>=" })
  add(actions, { id = "window.left", desc = "Window left", category = "windows", rhs = "<C-w>h" })
  add(actions, { id = "window.down", desc = "Window down", category = "windows", rhs = "<C-w>j" })
  add(actions, { id = "window.up", desc = "Window up", category = "windows", rhs = "<C-w>k" })
  add(actions, { id = "window.right", desc = "Window right", category = "windows", rhs = "<C-w>l" })

  -- LSP/diagnostics -------------------------------------------------------------
  add(actions, { id = "lsp.hover", desc = "Show hover documentation", category = "lsp", rhs = vim.lsp.buf.hover })
  add(actions, { id = "lsp.definition", desc = "Go to definition", category = "lsp", rhs = vim.lsp.buf.definition })
  add(actions, { id = "lsp.declaration", desc = "Go to declaration", category = "lsp", rhs = vim.lsp.buf.declaration })
  add(actions, { id = "lsp.implementation", desc = "Go to implementation", category = "lsp", rhs = vim.lsp.buf.implementation })
  add(actions, { id = "lsp.type_definition", desc = "Go to type definition", category = "lsp", rhs = vim.lsp.buf.type_definition })
  add(actions, { id = "lsp.references", desc = "Find references", category = "lsp", rhs = vim.lsp.buf.references })
  add(actions, { id = "lsp.rename", desc = "Rename symbol", category = "lsp", rhs = vim.lsp.buf.rename })
  add(actions, { id = "lsp.code_action", desc = "Code actions", category = "lsp", rhs = tiny_code_action })
  add(actions, { id = "lsp.format", desc = "Format buffer", category = "lsp", rhs = vim.lsp.buf.format })
  add(actions, { id = "diagnostic.line", desc = "Show line diagnostics", category = "diagnostics", rhs = function() vim.diagnostic.open_float({ scope = "line", border = "rounded" }) end })
  add(actions, { id = "diagnostic.cursor", desc = "Show cursor diagnostics", category = "diagnostics", rhs = function() vim.diagnostic.open_float({ scope = "cursor", border = "rounded" }) end })
  add(actions, { id = "diagnostic.next", desc = "Next diagnostic", category = "diagnostics", rhs = diagnostic_jump(1) })
  add(actions, { id = "diagnostic.prev", desc = "Previous diagnostic", category = "diagnostics", rhs = diagnostic_jump(-1) })
  add(actions, { id = "diagnostic.loclist", desc = "Diagnostics to location list", category = "diagnostics", rhs = vim.diagnostic.setloclist })

  -- Git -------------------------------------------------------------------------
  add(actions, { id = "git.status", desc = "Git status", category = "git", rhs = snacks_picker("git_status") })
  add(actions, { id = "git.commits", desc = "Git commits", category = "git", rhs = snacks_picker("git_log") })
  add(actions, { id = "git.branches", desc = "Git branches", category = "git", rhs = snacks_picker("git_branches") })
  add(actions, { id = "git.next_hunk", desc = "Next git hunk", category = "git", rhs = gitsigns("next_hunk") })
  add(actions, { id = "git.prev_hunk", desc = "Previous git hunk", category = "git", rhs = gitsigns("prev_hunk") })
  add(actions, { id = "git.preview_hunk", desc = "Preview git hunk", category = "git", rhs = gitsigns("preview_hunk") })
  add(actions, { id = "git.stage_hunk", desc = "Stage git hunk", category = "git", rhs = gitsigns("stage_hunk") })
  add(actions, { id = "git.reset_hunk", desc = "Reset git hunk", category = "git", rhs = gitsigns("reset_hunk") })
  add(actions, { id = "git.blame_line", desc = "Blame current line", category = "git", rhs = gitsigns("blame_line") })

  -- Misc ------------------------------------------------------------------------
  add(actions, { id = "ui.nohlsearch", desc = "Clear search highlight", category = "ui", rhs = cmd("nohlsearch") })
  add(actions, { id = "ui.close_floats", desc = "Close floating windows", category = "ui", rhs = close_floats })
  add(actions, { id = "ui.which_key_buffer", desc = "Show buffer-local keymaps", category = "ui", rhs = function() require("which-key").show({ global = false }) end })
end

local function add_user_commands(actions)
  for name, info in pairs(vim.api.nvim_get_commands({ builtin = false })) do
    add(actions, {
      id = "command." .. name,
      desc = info.desc ~= "" and info.desc or name,
      category = "commands",
      rhs = cmd(name),
    })
  end
end

local function add_existing_keymaps(actions)
  local seen = {}
  for _, mode in ipairs({ "n", "x", "i", "t", "c" }) do
    for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
      local desc = mapping.desc
      if desc and desc ~= "" and mapping.lhs and mapping.lhs ~= "" then
        local id = ("map.%s.%s"):format(mode, mapping.lhs)
        if not seen[id] then
          seen[id] = true
          add(actions, {
            id = id,
            desc = "Rebind: " .. desc,
            category = "existing maps",
            mode = mode,
            rhs = mapping.callback or mapping.rhs,
          })
        end
      end
    end
  end
end

function M.build()
  local actions = {}
  add_curated_actions(actions)
  add_user_commands(actions)
  add_existing_keymaps(actions)

  table.sort(actions, function(a, b)
    if a.category == b.category then
      return a.desc < b.desc
    end
    return a.category < b.category
  end)

  return actions
end

return M
