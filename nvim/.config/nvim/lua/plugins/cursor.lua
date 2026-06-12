return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  main = "smear_cursor",
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
    smear_insert_mode = false,
    -- Snacks already animates viewport scroll; draw cursor easing in screen
    -- space so motions that also scroll don't look like they lag behind text.
    scroll_buffer_space = false,
    particles_enabled = false,
    smear_terminal_mode = false,
    time_interval = 7, -- default 17ms
  },
}

-- TODO after writing file and tryingt omove cursor there is a weird jitter like cursor moves from top of the file to the bottom
