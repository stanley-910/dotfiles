-- nvim-luapad — live scratchpad for experimenting with Neovim's embedded Lua.
--
-- Use this as a learning workbench, not as a place for permanent config:
--   :Luapad  -> opens a live-evaluated scratch buffer
--   :LuaRun  -> runs the current buffer once as a Lua script
--
-- Safety rule: Luapad re-evaluates while you type, so avoid side-effect-heavy
-- APIs there (creating windows/autocmds/keymaps, file writes, shell commands).
-- Put those in a normal buffer and use :LuaRun when you want one explicit run.
--
--[[
Starter exercise: inspect the live Neovim UI from Luapad

1. Open a normal file first, for example:
     nvim nvim/.config/nvim/lua/config/keymap.lua

2. Run:
     :Luapad

3. Paste this into the Luapad buffer:

local wins = vim.api.nvim_list_wins()

for _, win in ipairs(wins) do
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_line_count(buf)
  local cursor = vim.api.nvim_win_get_cursor(win)

  print({
    win = win,
    buf = buf,
    name = name,
    lines = lines,
    row = cursor[1],
    col = cursor[2],
  })
end

4. Play:
   - Move your cursor in the original file.
   - Come back to Luapad and watch row/col change.
   - Open another split or buffer and watch nvim_list_wins() report more windows.

Read these help tags in order:
  :help lua-guide-api
  :help nvim_list_wins()
  :help nvim_win_get_buf()
  :help nvim_buf_get_name()
  :help nvim_buf_line_count()
  :help nvim_win_get_cursor()

Notice:
  - Nvim API functions often accept 0 as "current buffer/window".
  - Explicit buffer/window ids are better when inspecting multiple windows.
  - nvim_win_get_cursor() returns { row, col } with 1-indexed row and 0-indexed col.

Good Luapad APIs to start with:
  vim.api.nvim_get_current_buf()
  vim.api.nvim_list_wins()
  vim.api.nvim_buf_get_name(...)
  vim.api.nvim_win_get_cursor(...)
  vim.opt.runtimepath:get()

Avoid in live-eval until you know exactly what will repeat:
  vim.keymap.set(...)
  vim.api.nvim_create_autocmd(...)
  vim.api.nvim_open_win(...)
  vim.fn.system(...)
  vim.cmd("write")
]]
return {
  "rafcamlet/nvim-luapad",

  -- Command-based lazy-loading keeps startup clean while making the commands
  -- available for scratch experiments.
  cmd = { "Luapad", "LuaRun", "Lua" },

  opts = {
    -- Horizontal keeps the scratchpad close to a notebook/repl feel without
    -- stealing the full screen from the file you are inspecting.
    split_orientation = "horizontal",

    -- Show captured print() output and errors inline as virtual text/floats.
    preview = true,
    error_indicator = true,

    -- Keep live evaluation on for small pure expressions; use :LuaRun for code
    -- that mutates editor state.
    eval_on_change = true,
    eval_on_move = false,

    -- Tiny convenience for scratch output. Prefer spelling vim.* APIs directly
    -- while learning, but inspect(...) is nice for table dumps.
    context = {
      inspect = vim.inspect,
    },
  },
}
