return {
  "saghen/blink.indent",
  -- Temporarily disabled in favor of snacks.indent (see snacks.lua). lazy skips
  -- loading this but keeps the spec; flip back to `true` (or delete the line) to
  -- restore. Both draw guides on the same columns, so only ONE may be enabled.
  enabled = false,
  opts = {
    static = {
      enabled = true,
      char = "╎",
      highlights = { "BlinkIndentDim" },
    },
    scope = {
      enabled = true,
      char = "╎",
      -- Kanagawa's Comment highlight is a slightly brighter grey than
      -- Whitespace, so the active scope stays muted but easier to see.
      highlights = { "Comment" },
      underline = {
        enabled = false,
      },
    },
  },
  config = function(_, opts)
    local function blend(fg, bg, alpha)
      local function channel(color, divisor)
        return math.floor(color / divisor) % 256
      end

      local r = math.floor(channel(fg, 65536) * alpha + channel(bg, 65536) * (1 - alpha) + 0.5)
      local g = math.floor(channel(fg, 256) * alpha + channel(bg, 256) * (1 - alpha) + 0.5)
      local b = math.floor(channel(fg, 1) * alpha + channel(bg, 1) * (1 - alpha) + 0.5)

      return r * 65536 + g * 256 + b
    end

    local function set_highlights()
      local whitespace = vim.api.nvim_get_hl(0, { name = "Whitespace", link = false })
      local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })

      if whitespace.fg and normal.bg then
        vim.api.nvim_set_hl(0, "BlinkIndentDim", {
          fg = blend(whitespace.fg, normal.bg, 0.5),
        })
      else
        vim.api.nvim_set_hl(0, "BlinkIndentDim", { link = "BlinkIndent" })
      end
    end

    set_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("config_blink_indent", { clear = true }),
      callback = set_highlights,
    })

    require("blink.indent").setup(opts)
  end,
}
