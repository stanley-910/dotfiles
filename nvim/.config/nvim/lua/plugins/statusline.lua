local filetype_labels = {
  typescriptreact = "tsx",
  javascriptreact = "jsx",
}

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      options = {
        theme = "kanagawa",
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
          "encoding",
          "fileformat",
          {
            "filetype",
            fmt = function(filetype)
              return filetype_labels[filetype] or filetype
            end,
          },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}
