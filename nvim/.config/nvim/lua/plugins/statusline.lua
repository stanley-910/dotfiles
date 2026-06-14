local filetype_labels = {
  typescriptreact = "tsx",
  javascriptreact = "jsx",
}

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons" },
    -- opts is a function (not a table) because the dashboard extension below
    -- resolves tokyodark palette colors at load time — tokyodark is in the rtp
    -- by then (priority 1000), but not yet when this spec file is collected.
    opts = function()
      -- Minimal "DASH" bar shown only for the snacks_dashboard filetype
      -- (the Mission Control strip from the dashboard design handoff):
      --   [DASH] ~/cwd  weather ............ utf-8 · fri jun 12 [21:42:08]
      -- Weather comes from the dashboard's own cached wx fetch.
      local ok, tokyodark = pcall(function()
        return require("tokyodark.colors").setup({ theme = "wave" }).palette
      end)
      local p = ok and tokyodark or {}
      local dash_extension = {
        filetypes = { "snacks_dashboard" },
        sections = {
          lualine_a = {
            {
              function()
                return "DASH"
              end,
              color = { fg = p.sumiInk0, bg = p.carpYellow, gui = "bold" },
            },
          },
          lualine_b = {
            {
              function()
                return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
              end,
              color = { fg = p.springViolet2 },
            },
          },
        },
      }

      return {
        options = {
          theme = "tokyodark",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(mode)
                if mode == "COMMAND" then
                  local cmdtype = vim.fn.getcmdtype()

                  if cmdtype == "/" then
                    return "SEARCH"
                  elseif cmdtype == "?" then
                    return "R-SEARCH"
                  end
                end
                return mode
              end,
            },
          },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = {
            -- "encoding",
            -- "fileformat",
            {
              "filetype",
              fmt = function(filetype)
                return filetype_labels[filetype] or filetype
              end,
            },
          },
          lualine_y = { "progress" },
          -- lualine_z = { "location" },
        },
        extensions = { dash_extension },
      }
    end,
  },
}
