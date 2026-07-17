local M = {}

local directions = {
  h = { wincmd = "h", tmux = "L" },
  j = { wincmd = "j", tmux = "D" },
  k = { wincmd = "k", tmux = "U" },
  l = { wincmd = "l", tmux = "R" },
}

function M.move(direction_key)
  local direction = directions[direction_key]
  if not direction then
    return
  end

  local before = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(direction.wincmd)

  if vim.api.nvim_get_current_win() ~= before or not vim.env.TMUX then
    return
  end

  vim.fn.system({ "tmux", "select-pane", "-" .. direction.tmux })
end

return M
