return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  main = "smear_cursor",
  enabled = true,
  config = function(_, opts)
    local smear = require("smear_cursor")
    smear.setup(opts)

    local disabled_by_picker = false
    local restore_enabled = nil

    local function current_window_is_snacks_picker()
      return vim.bo.filetype:match("^snacks_picker_") ~= nil
          or vim.w.snacks_picker_preview == true
    end

    local function update()
      if current_window_is_snacks_picker() then
        if not disabled_by_picker then
          restore_enabled = smear.enabled
        end
        disabled_by_picker = true

        if smear.enabled then
          smear.enabled = false
        end
      elseif disabled_by_picker then
        disabled_by_picker = false

        if restore_enabled and not smear.enabled then
          smear.enabled = true
        end
        restore_enabled = nil
      end
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "WinEnter" }, {
      group = vim.api.nvim_create_augroup("SmearCursorSnacksPicker", { clear = true }),
      desc = "Disable smear-cursor inside Snacks picker windows",
      callback = update,
    })
  end,
  opts = {
    -- README preset: smooth cursor without a long smear/trail. This keeps the
    -- cursor rectangular while easing visible jumps like paragraph motions.
    stiffness = 0.9,
    trailing_stiffness = 0.9,
    matrix_pixel_threshold = 0.5,

    damping = 0.95,
    distance_stop_animating = 0.8,

    smear_between_buffers = false,
    smear_to_cmd = false,

    smear_insert_mode = true,
    stiffness_insert_mode = 0.9,
    trailing_stiffness_insert_mode = 0.9,
    damping_insert_mode = 0.95,
    -- Snacks already animates viewport scroll; draw cursor easing in screen
    -- space so motions that also scroll don't look like they lag behind text.
    scroll_buffer_space = false,
    particles_enabled = false,
    smear_terminal_mode = false,
    time_interval = 7, -- default 17ms

  },
}

-- TODO after writing file and tryingt omove cursor there is a weird jitter like cursor moves from top of the file to the bottom
