-- "Left hand line numbers" — comfy-line-numbers.nvim.
--
-- Shows relative line numbers using only left-hand digits (1-5, 11-15, 21-25,
-- ...) and remaps j/k so e.g. `11j` performs the original `6j`. Keeps the left
-- hand on digits and the right hand on j/k. Requires 'relativenumber', which is
-- already set in lua/config/options.lua.
--
-- Defaults (labels, up_key=k, down_key=j, hidden buffer/file types) are already
-- sensible per the README, so opts stays empty until a real need appears.
-- See: https://github.com/mluders/comfy-line-numbers.nvim
return {
  {
    "mluders/comfy-line-numbers.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
