-- Keymaps migrated from Zed keymap.json and the current IdeaVim config.
-- Source-of-truth note: dotfiles/jetbrains/.ideavimrc and ~/.ideavimrc are identical;
-- dotfiles/jetbrains/.config/jetbrains/.ideavimrc is older. Zed keymaps are newer,
-- so Zed wins where the same key changed behavior.
--
-- Docs to keep handy while editing this file:
--   :help vim.keymap.set()
--   :help keycodes
--   :help mapleader
--   :help windows
--   :help tabpage
--   :help vim.lsp.buf
--   :help diagnostic-defaults

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local map = vim.keymap.set

-- Group our autocmds so re-sourcing this file replaces old callbacks instead
-- of stacking duplicates. See :help nvim_create_augroup().
local keymap_group = vim.api.nvim_create_augroup("UserKeymaps", { clear = true })

-- Standard keymap options helper: every map gets a description for :map/which-key
-- style discovery, stays quiet in the command line, and can be extended with
-- buffer-local options such as { buffer = event.buf }.
local function opts(desc, extra)
  return vim.tbl_extend("force", {
    silent = true,
    desc = desc,
  }, extra or {})
end

-- Turn an Ex command name into a keymap RHS. <cmd> avoids entering command-line
-- mode like ':' mappings do, and <CR> executes it.
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

-- Search for the current visual selection literally. Use scratch register z,
-- restore it afterward, then seed the / search register with \V "very nomagic"
-- text so punctuation in the selection is not treated as regex syntax.
local function visual_search_selection()
  local previous_register = vim.fn.getreg("z")
  local previous_register_type = vim.fn.getregtype("z")

  vim.cmd([[normal! "zy]])
  local text = vim.fn.getreg("z")
  vim.fn.setreg("z", previous_register, previous_register_type)

  if text == "" then
    return
  end

  text = text:gsub("\n", [[\n]])
  vim.fn.setreg("/", [[\V]] .. vim.fn.escape(text, [[\/]]))
  vim.cmd("normal! nzzzv")
end
-- Question::use /teach skill to teach me about Vim 'magic' modes for substitution and regex search
--

vim.api.nvim_create_user_command("CloseFloatingWindows", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, false)
    end
  end
end, { desc = "Close all floating windows" })

-- Hide flash.nvim's char-mode (f/F/t/T) highlight overlay.
--
-- WHY this exists: flash clears its char highlights via a vim.on_key listener
-- that checks for a literal <Esc>. But vim.on_key sees the key AFTER mappings,
-- and our <Esc> map below rewrites Esc into <cmd>nohlsearch...<CR>, so flash
-- never sees a bare <Esc> and the overlay lingers (esp. after `f f f`).
--
-- FRAGILE: reaches into the flash internal module `flash.plugins.char` and its
-- `state:hide()` method. flash exposes no public clear API. Revisit after flash
-- updates. pcall keeps a renamed/removed internal from breaking <Esc>.
vim.api.nvim_create_user_command("FlashClear", function()
  local ok, char = pcall(require, "flash.plugins.char")
  if ok and char.state and char.state.visible then
    pcall(function()
      char.state:hide()
    end)
  end
end, { desc = "Hide flash char-mode highlights" })

-- -----------------------------------------------------------------------------
-- Movement
-- -----------------------------------------------------------------------------


map({ "n", "x" }, "H", "^", opts("Start of Line"))
map({ "n", "x" }, "L", "$", opts("End of Line"))

-- Zed's current mapping uses larger vertical jumps here. The older IdeaVim file
-- used ]m/[m method motions, but Zed is the newer active editor config.
map({ "n", "x" }, "<C-j>", "8j", opts("Move down 8 lines"))
map({ "n", "x" }, "<C-k>", "8k", opts("Move up 8 lines"))

map("n", "n", "nzzzv", opts("Next search result centered"))
map("n", "N", "Nzzzv", opts("Previous search result centered"))
-- map("n", "<C-d>", "<C-d>zz", opts("Half-page down centered"))
-- map("n", "<C-u>", "<C-u>zz", opts("Half-page up centered"))
map("n", "''", "''zz", opts("Jump back centered"))
map("n", "zl", "15zl", opts("Scroll right 15 columns"))
map("n", "zh", "15zh", opts("Scroll left 15 columns"))


-- Use display-line movement in wrapped prose buffers, matching the Zed markdown
-- and Typst special-case.
vim.api.nvim_create_autocmd("FileType", {
  group = keymap_group,
  pattern = { "markdown", "typst" },
  callback = function(event)
    map("n", "j", "gj", opts("Display line down", { buffer = event.buf }))
    map("n", "k", "gk", opts("Display line up", { buffer = event.buf }))
  end,
})


vim.api.nvim_create_autocmd("FileType", {
  group = keymap_group,
  pattern = "qf",
  callback = function(event)
    map("n", "<CR>", function()
      local wininfo = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
      if wininfo and wininfo.loclist == 1 then
        vim.cmd(".ll")
      else
        vim.cmd(".cc")
      end
    end, opts("Open quickfix item", { buffer = event.buf }))
  end,
})

-- -----------------------------------------------------------------------------
-- Windows, buffers, files, terminal
-- -----------------------------------------------------------------------------

map("n", "<leader>v", cmd("vsplit"), opts("Split vertically"))
map("n", "<Tab>", cmd("bnext"), opts("Next buffer"))
map("n", "<S-Tab>", cmd("bprevious"), opts("Previous buffer"))
-- Keep native <C-w>c / <C-w>C behavior: close the current window/split.
-- Buffer deletion belongs on explicit :bdelete / quickbind buffer actions.

map({ "n", "i", "t" }, "<M-h>", "<C-\\><C-n><C-w>h", opts("Window left"))
map({ "n", "i", "t" }, "<M-l>", "<C-\\><C-n><C-w>l", opts("Window right"))

-- Move the current line (normal) or selection (visual) up/down. `:m` moves a
-- line to after {address}; `.+1` is the line below, `.-2` is the line above the
-- one before. `==` reindents the moved line. In visual mode `'<`/`'>` are the
-- selection bounds, and `gv=gv` reselects + reindents so the moves can repeat.
-- See :help :move and :help '< .
map("n", "<M-j>", cmd("m .+1") .. "==", opts("Move line down"))
map("n", "<M-k>", cmd("m .-2") .. "==", opts("Move line up"))
map("x", "<M-j>", ":m '>+1<CR>gv=gv", opts("Move selection down"))
map("x", "<M-k>", ":m '<-2<CR>gv=gv", opts("Move selection up"))

map("t", "<Esc>", "<C-\\><C-n>", opts("Terminal normal mode"))

-- Terminal toggle (<M-/>) now lives in lua/plugins/snacks.lua via
-- Snacks.terminal.toggle(). The global single-<Esc> map above still governs
-- native/dap terminals; inside snacks terminals the buffer-local double-<Esc>
-- takes precedence (single <Esc> passes through to the running TUI).

map("n", "-", function()
  local oil = require_or_notify("oil", "oil.nvim")
  if oil then
    oil.open()
  end
end, opts("Open parent directory in Oil"))

-- -----------------------------------------------------------------------------
-- Find/search/navigation UI
-- -----------------------------------------------------------------------------

-- local snacks = require("snacks")
-- vim.print(snacks.picker)

-- map({ "n", "v" }, "<leader><leader>", snacks_picker("files"), opts("Find files"))
-- map("n", "<leader>/", snacks_picker("grep"), opts("Find in project"))
-- map("n", "<leader>gl", snacks_picker("git_log"), opts("Git Grep"))
-- map("n", "<leader>gd", snacks_picker("git_diff"), opts("Git Grep"))

map("x", "/", visual_search_selection, opts("Search visual selection"))
-- `:nohlsearch` hides current highlights without changing 'hlsearch', so the
-- next search automatically highlights matches again. Keep that part as a raw
-- command because `:help :nohlsearch` notes it does not work reliably from user
-- functions/autocommands. Then close transient floats like LSP hover/diagnostics.
-- FlashClear is appended so a lingering flash f/t overlay also clears here,
-- since flash's own <Esc> detection is defeated by these very mappings.
map("n", "<Esc>", "<cmd>nohlsearch<CR><cmd>CloseFloatingWindows<CR><cmd>FlashClear<CR>",
  opts("Clear search highlight, floats, and flash"))
map("n", "<C-c>", "<cmd>nohlsearch<CR><cmd>CloseFloatingWindows<CR><cmd>FlashClear<CR>",
  opts("Clear search highlight, floats, and flash"))

-- Snacks picker/gitbrowse owns <leader>g* maps in lua/plugins/snacks.lua.

-- -----------------------------------------------------------------------------
-- Editing
-- -----------------------------------------------------------------------------

-- map("n", "Q", vim.lsp.buf.code_action, opts("Code actions"))
map({ "n", "x" }, "Q", function()
  require("tiny-code-action").code_action()
end, opts("Code actions"))

map("n", "R", ".", opts("Repeat last change"))
map("n", "Y", "y$", opts("Yank to end of line"))
map("x", "Y", "y", opts("Yank selection"))
-- Zed muscle memory: jump to the value after the last '=' on the current line.
map("n", "D", "$F=w", opts("Jump to value after ="))

map("n", "<CR>", "ciw", opts("Change inner word"))
map("n", "<S-CR>", "ciW", opts("Change inner WORD"))
map("n", "<C-CR>", "viw", opts("Select inner word"))

vim.api.nvim_create_autocmd("CmdwinEnter", {
  group = keymap_group,
  callback = function(_)
    -- The command-line window uses normal mode, so the global <CR> -> ciw map
    -- would otherwise block executing history entries. Restore cmdwin's native
    -- <CR> behavior only for this special buffer. See :help cmdwin.
    map("n", "<CR>", "<CR>", opts("Execute command-line window entry", { buffer = true }))
  end,
})

map("n", "<leader>o", "O<Esc>jo<Esc>", opts("Open surrounding blank lines"))
map("n", "<leader>y", cmd("%yank"), opts("Yank whole buffer"))
-- Reselect after visual indent without putting `gv` in the redo stream.
-- Returning the native operator keeps :help visual-repeat intact, while the
-- scheduled `gv` restores the selection for repeated manual indents.
local function visual_indent_and_reselect(operator)
  return function()
    vim.schedule(function()
      vim.cmd("normal! gv")
    end)
    return operator
  end
end

map("x", "<", visual_indent_and_reselect("<"), opts("Indent left and reselect", { expr = true }))
map("x", ">", visual_indent_and_reselect(">"), opts("Indent right and reselect", { expr = true }))
map("x", "@", ":normal @@<CR>", opts("Run macro on selection", { silent = false }))

-- -----------------------------------------------------------------------------
-- Insert and command-line editing
-- -----------------------------------------------------------------------------

map("i", "kj", "<Esc>l", opts("Normal mode, move right"))

map("i", "<C-h>", "<Left>", opts("Move left"))
map("i", "<C-j>", "<Down>", opts("Move down"))
map("i", "<C-k>", "<Up>", opts("Move up"))
map("i", "<C-l>", "<Right>", opts("Move right"))

map("i", "<C-a>", "<C-o>I", opts("Beginning of line"))
map("i", "<C-e>", "<C-o>A", opts("End of line"))
map("i", "<M-d>", " <Esc>ce", opts("Change next word"))
map("i", "<M-BS>", "<C-w>", opts("Delete word back"))
map("i", "<C-p>", "<C-o>{", opts("Previous paragraph"))
map("i", "<C-n>", "<C-o>}", opts("Next paragraph"))
map("i", "<C-S-n>", "<C-c>o", opts("Open line below")) -- use in conjunction with C-n


-- Command-line history. Blink cmdline completion explicitly disables these
-- keys so Neovim can use them for history; see :help c_CTRL-P and :help c_CTRL-N.
map("c", "<C-p>", "<Up>", opts("Command history previous", { silent = false }))
map("c", "<C-n>", "<Down>", opts("Command history next", { silent = false }))


-- -----------------------------------------------------------------------------
-- Selection/text-object muscle memory
-- -----------------------------------------------------------------------------

-- Picker-window detection helper kept for future smart bindings: Snacks previews
-- can display a real source buffer, so picker-local maps are not guaranteed to be
-- present from the preview pane. A smart binding can call this first, handle the
-- picker case, then fall back to its normal behavior.
---@diagnostic disable-next-line: unused-function, unused-local
local function cycle_snacks_picker_window()
  local snacks = require_or_notify("snacks", "snacks.nvim")
  if not snacks or not snacks.picker or not snacks.picker.get then
    return false
  end

  local ok, actions = pcall(require, "snacks.picker.actions")
  if not ok then
    return false
  end

  local current_win = vim.api.nvim_get_current_win()
  for _, picker in ipairs(snacks.picker.get()) do
    local input_win = picker.input and picker.input.win and picker.input.win.win
    local list_win = picker.list and picker.list.win and picker.list.win.win
    local preview_win = picker.preview and picker.preview.win and picker.preview.win.win

    if current_win == input_win or current_win == list_win or current_win == preview_win then
      actions.cycle_win(picker)
      return true
    end
  end

  return false
end

map({ "n", "i" }, "<M-w>", function()
  if cycle_snacks_picker_window() then
    return
  end

  vim.cmd("wincmd w")
end, opts("Cycle picker/window"))

-- -----------------------------------------------------------------------------
-- LSP and diagnostics
-- -----------------------------------------------------------------------------

-- Snacks picker owns gd/gD/gI/gy/grr/gs/gS in lua/plugins/snacks.lua.

-- Format/Lint
vim.keymap.set('n', '<leader>l', function()
  -- use conform when formatter available, but fallback to lsp when not
  require('conform').format({ async = true, lsp_format = 'fallback' })
end, { desc = 'Format file' })

-- -----------------------------------------------------------------------------
-- Debugger: core nvim-dap controls. UI/adapters are configured separately.
-- -----------------------------------------------------------------------------

local function dap_action(action)
  return function()
    local dap = require_or_notify("dap", "nvim-dap")
    if dap then
      dap[action]()
    end
  end
end

local function dap_view_action(action)
  return function()
    local dap_view = require_or_notify("dap-view", "nvim-dap-view")
    if dap_view then
      dap_view[action]()
    end
  end
end

local function dap_breakpoints()
  return require("config.dap_breakpoints")
end

local function set_repeat(plug)
  -- repeat.vim exposes repeat#set as an autoload function; calling it once is
  -- what loads it, so exists('*repeat#set') is false before the first call.
  pcall(vim.fn["repeat#set"], vim.keycode(plug), vim.v.count)
end

vim.keymap.set("n", "<Plug>(dap-toggle-breakpoint)", function()
  dap_breakpoints().toggle()
  set_repeat("<Plug>(dap-toggle-breakpoint)")
end, { silent = true, desc = "Toggle breakpoint" })

map("n", "<leader>dd", dap_action("continue"), opts("Debug continue/start"))
map("n", "<leader>db", "<Plug>(dap-toggle-breakpoint)", opts("Toggle breakpoint", { remap = true }))
map("n", "<leader>dc", function()
  dap_breakpoints().set_conditional()
end, opts("Set conditional breakpoint"))
map("n", "<leader>dH", function()
  dap_breakpoints().set_hit_condition()
end, opts("Set breakpoint hit condition"))
map("n", "<leader>dl", function()
  dap_breakpoints().set_log_point()
end, opts("Set logpoint"))
map("n", "<leader>d?", function()
  dap_breakpoints().inspect_current()
end, opts("Inspect breakpoint"))
map("n", "<leader>dr", dap_action("run_last"), opts("Rerun last debug session"))
map("n", "<leader>dU", dap_view_action("toggle"), opts("Toggle debug UI"))

map("n", "]b", function()
  dap_breakpoints().jump(1)
end, opts("Next breakpoint"))
map("n", "[b", function()
  dap_breakpoints().jump(-1)
end, opts("Previous breakpoint"))
map("n", "<leader>dB", function()
  dap_breakpoints().pick()
end, opts("Search debug breakpoints"))

local function open_scratch_output(text)
  vim.cmd("botright 12split")
  vim.cmd("enew")

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.cmd.wincmd("L")

  local lines = vim.split(text ~= "" and text or "(no output)", "\n", { plain = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modified = false
end

vim.api.nvim_create_user_command("LuaOutput", function(ctx)
  local lua_cmd = ("%d,%dlua"):format(ctx.line1, ctx.line2)

  local ok, result = pcall(vim.api.nvim_exec2, lua_cmd, { output = true })

  if ok then
    open_scratch_output(result.output)
  else
    open_scratch_output(result)
  end
end, { range = true })


map("x", "<leader>r", cmd("'<,'>LuaOutput"), opts("run visual selection to split"))
map("n", "<leader>r", cmd(".LuaOutput"), opts("run line to split"))

map("n", "<M-x>", "x", opts("delete char"))

map("n", "<leader>qa", cmd("qall"), opts("quit session"))


map("n", "<leader>bo", cmd("BufferOrderByBufferNumber"), opts("Order buffers/#"))
