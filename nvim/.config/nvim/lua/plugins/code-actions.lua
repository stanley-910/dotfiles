local numeric_aliases = {
  ["1"] = "q",
  ["2"] = "w",
  ["3"] = "e",
}

local sticky_preview = {}

local function apply_displayed_hotkey(win, buf, hotkey)
  if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:match("%[" .. hotkey .. "%s*%]") then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { line_number, 0 })
      vim.api.nvim_feedkeys(vim.keycode("<CR>"), "m", false)
      return
    end
  end
end

local function action_lines(buf)
  local result = {}

  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:match("^%s*%[[^%]]+%]") then
      result[#result + 1] = line_number
    end
  end

  return result
end

local function move_action_cursor(win, buf, direction)
  if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local selectable = action_lines(buf)
  if #selectable == 0 then
    return
  end

  local current = vim.api.nvim_win_get_cursor(win)[1]
  local target

  if direction > 0 then
    for _, line in ipairs(selectable) do
      if line > current then
        target = line
        break
      end
    end
    target = target or selectable[1]
  else
    for index = #selectable, 1, -1 do
      local line = selectable[index]
      if line < current then
        target = line
        break
      end
    end
    target = target or selectable[#selectable]
  end

  vim.api.nvim_win_set_cursor(win, { target, 0 })
end

local function current_preview_callback(buf)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == "K" and map.callback then
      return map.callback
    end
  end
end

local function close_preview()
  local ok, preview = pcall(require, "tiny-code-action.pickers.buffer_utils.preview")
  if ok then
    preview.close_preview()
  end
end

local function refresh_sticky_preview(win, buf, preview_callback)
  if not sticky_preview[buf] or not preview_callback then
    return
  end

  close_preview()
  vim.schedule(function()
    if sticky_preview[buf] and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_set_current_win(win)
      preview_callback()
    end
  end)
end

local function install_numeric_aliases()
  local group = vim.api.nvim_create_augroup("UserTinyCodeActionAliases", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "TinyCodeActionWindowEnterMain",
    callback = function(event)
      local buf = event.data and event.data.buf
      local win = event.data and event.data.win
      if not (buf and win) then
        return
      end

      vim.schedule(function()
        if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
          return
        end

        local preview_callback = current_preview_callback(buf)

        for number, hotkey in pairs(numeric_aliases) do
          vim.keymap.set("n", number, function()
            apply_displayed_hotkey(win, buf, hotkey)
          end, {
            buffer = buf,
            nowait = true,
            silent = true,
            desc = "Apply code action [" .. hotkey .. "]",
          })
        end

        vim.keymap.set("n", "j", function()
          move_action_cursor(win, buf, 1)
          refresh_sticky_preview(win, buf, preview_callback)
        end, { buffer = buf, nowait = true, silent = true, desc = "Next code action" })

        vim.keymap.set("n", "k", function()
          move_action_cursor(win, buf, -1)
          refresh_sticky_preview(win, buf, preview_callback)
        end, { buffer = buf, nowait = true, silent = true, desc = "Previous code action" })

        vim.keymap.set("n", "K", function()
          sticky_preview[buf] = not sticky_preview[buf]

          if sticky_preview[buf] then
            close_preview()
            if preview_callback then
              preview_callback()
            end
          else
            close_preview()
          end
        end, { buffer = buf, nowait = true, silent = true, desc = "Toggle code action preview" })

        vim.api.nvim_create_autocmd("BufWipeout", {
          buffer = buf,
          once = true,
          callback = function()
            sticky_preview[buf] = nil
          end,
        })
      end)
    end,
  })
end

return {
  {
    "rachartier/tiny-code-action.nvim",
    event = "LspAttach",
    opts = {
      -- Use diff-so-fancy for richer code-action previews. tiny-code-action
      -- also supports "vim" (built-in vim.diff), "delta", and "difftastic".
      backend = "diffsofancy",

      picker = {
        "buffer",
        opts = {
          -- Enables single-key labels next to actions.
          hotkeys = true,

          -- Make the first three actions home-row adjacent. tiny-code-action
          -- automatically maps uppercase aliases for single-character hotkeys,
          -- so q/w/e also gives Q/W/E. The autocmd above adds 1/2/3 aliases.
          hotkeys_mode = function(titles, _used_hotkeys)
            local preferred = {
              "q", "w", "e",
              "4", "5", "6", "7", "8", "9", "0",
              "a", "s", "d", "f", "g",
            }

            local keys = {}
            for i = 1, #titles do
              keys[i] = preferred[i] or tostring(i)
            end
            return keys
          end,

          -- Pressing the hotkey applies the action immediately.
          auto_accept = true,

          -- Put the action picker at the cursor.
          position = "cursor",

          -- Keep preview manual at first so it doesn't obscure context.
          -- Press K inside the picker to preview.
          -- does this do anything?
          -- picker = {
          --   "snacks",
          --   opts = {
          --     layout = "vertical",
          --   },
          -- },

          auto_preview = false,

          winborder = "rounded",

          keymaps = {
            preview = "K",
            -- q/Q are action hotkeys now; use Esc to close without applying.
            close = "<Esc>",
            select = "<CR>",
            preview_close = { "q", "<Esc>" },
          },
        },
      },
    },
    config = function(_, opts)
      require("tiny-code-action").setup(opts)
      install_numeric_aliases()
    end,
  },
}
