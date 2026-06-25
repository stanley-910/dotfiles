return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- opts is a function (not a table) because the dashboard extension below
    -- resolves kanagawa palette colors at load time — kanagawa is in the rtp
    -- by then (priority 1000), but not yet when this spec file is collected.
    opts = function()
      local statusline = require("config.statusline")
      local ok, kanagawa = pcall(function()
        return require("kanagawa.colors").setup({ theme = "wave" }).palette
      end)
      local p = ok and kanagawa or {}

      statusline.setup_autocmds()

      return {
        options = {
          theme = "kanagawa",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { statusline.mode() },
          lualine_b = { { "branch", icons_enabled = false }, "diff", "diagnostics" },
          lualine_c = {
            statusline.buffer_directory(),
            statusline.recording(p),
            statusline.searchcount(p),
            -- showcmd / pending operators, routed here by showcmdloc=statusline.
            "%S",
          },
          lualine_x = {
            -- "encoding",
            -- "fileformat",
            statusline.session_autosave(p),
            statusline.pomodoro(p),
            statusline.lsp(p),
            -- {
            --   "filetype",
            --   colored = true,
            --   icon_only = true,
            -- },
          },
          lualine_y = { "progress" },
          lualine_z = {},
        },
        extensions = { statusline.dashboard_extension(p) },
      }
    end,
  },
}
