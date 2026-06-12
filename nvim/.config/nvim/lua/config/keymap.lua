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

-- Build Telescope callbacks without requiring telescope at startup. If Telescope
-- ever gets removed/renamed, the keymap reports a useful warning instead of
-- throwing a Lua stack trace.
local function telescope(picker, picker_opts)
  return function()
    local builtin = require_or_notify("telescope.builtin", "telescope.nvim")
    if builtin then
      builtin[picker](picker_opts or {})
    end
  end
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
-- Native <C-w>c closes a window and errors with E444 in a single-window
-- buffer-cycling workflow. snacks.bufdelete deletes the buffer while KEEPING
-- the window/split (plain :bdelete would also close the split). Deferred in a
-- function so the module is resolved at press time.
map("n", "<C-w>c", function()
  require("snacks.bufdelete")()
end, opts("Delete buffer (keep window)"))
map("n", "<C-w>C", function()
  require("snacks.bufdelete")()
end, opts("Delete buffer (keep window)"))

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

-- Terminal toggle state:
--   bufnr remembers the terminal buffer/process so reopening keeps the same shell.
--   winid remembers the visible split so the next toggle can close only that window.
local terminal = { bufnr = nil, winid = nil }

local function toggle_terminal()
  if terminal.winid and vim.api.nvim_win_is_valid(terminal.winid) then
    vim.api.nvim_win_close(terminal.winid, true)
    terminal.winid = nil
    return
  end

  vim.cmd("botright split")
  terminal.winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(terminal.winid, 12)

  if terminal.bufnr and vim.api.nvim_buf_is_valid(terminal.bufnr) then
    vim.api.nvim_win_set_buf(terminal.winid, terminal.bufnr)
  else
    vim.cmd("terminal")
    terminal.bufnr = vim.api.nvim_get_current_buf()
  end

  vim.cmd("startinsert")
end

map({ "n", "t" }, "<M-/>", toggle_terminal, opts("Toggle terminal"))

map("n", "-", function()
  local oil = require_or_notify("oil", "oil.nvim")
  if oil then
    oil.open()
  end
end, opts("Open parent directory in Oil"))

-- -----------------------------------------------------------------------------
-- Find/search/navigation UI
-- -----------------------------------------------------------------------------

map({ "n", "v" }, "<leader><leader>", telescope("find_files"), opts("Find files"))
map("n", "<leader>/", telescope("live_grep"), opts("Find in project"))
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

map("n", "gs", telescope("lsp_document_symbols"), opts("Document symbols"))

-- <leader>g* was unused when added; gitsigns currently owns <leader>h*.
map({ "n", "x" }, "<leader>gb", function()
  require("snacks.gitbrowse")()
end, opts("Open git URL in browser"))

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
  callback = function(event)
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

map("n", "<M-w>", "viw", opts("Select inner word"))
map("x", "<M-w>", "w", opts("Extend to next word"))
map("i", "<M-w>", "<Esc>viw", opts("Select inner word"))
map("n", "<M-b>", "evb", opts("Select previous word-ish"))
map("x", "<M-b>", "b", opts("Extend to previous word"))
map("i", "<M-b>", "<Esc>evb", opts("Select previous word-ish"))
map("n", "<M-e>", "viw", opts("Select inner word"))
map("x", "<M-e>", "e", opts("Extend to word end"))

-- x{motion} replacement is handled by gbprod/substitute.nvim. That keeps the
-- old xiw/xa" muscle memory while making any future text object work without
-- adding another explicit keymap here.

-- -----------------------------------------------------------------------------
-- LSP and diagnostics
-- -----------------------------------------------------------------------------

map("n", "gD", function()
  vim.cmd("vsplit")
  vim.lsp.buf.declaration()
end, opts("Declaration in vertical split"))
map("n", "gI", vim.lsp.buf.implementation, opts("Go to implementation"))
map("n", "gy", vim.lsp.buf.type_definition, opts("Go to type definition"))


-- Format/Lint
map("n", "<leader>l", vim.lsp.buf.format, opts("Format buffer")) -- theres an issue with diagnostics not reattaching after I go back from normal mode to insert back to insert?

-- -----------------------------------------------------------------------------
-- Debugger placeholders: become real once nvim-dap/nvim-dap-python are installed.
-- -----------------------------------------------------------------------------

map("n", "<leader>d", function()
  local dap = require_or_notify("dap", "nvim-dap")
  if dap then
    dap.continue()
  end
end, opts("Debug/continue"))

map("n", "<leader>b", function()
  local dap = require_or_notify("dap", "nvim-dap")
  if dap then
    dap.toggle_breakpoint()
  end
end, opts("Toggle breakpoint"))

map("n", "<leader>R", function()
  local dap = require_or_notify("dap", "nvim-dap")
  if dap then
    dap.run_last()
  end
end, opts("Rerun last debug session"))
