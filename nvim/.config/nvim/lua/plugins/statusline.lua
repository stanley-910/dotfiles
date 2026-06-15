local filetype_labels = {
  typescriptreact = "tsx",
  javascriptreact = "jsx",
}

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons" },
    -- opts is a function (not a table) because the dashboard extension below
    -- resolves kanagawa palette colors at load time — kanagawa is in the rtp
    -- by then (priority 1000), but not yet when this spec file is collected.
    opts = function()
      -- Minimal "DASH" bar shown only for the snacks_dashboard filetype
      -- (the Mission Control strip from the dashboard design handoff):
      --   [DASH] ~/cwd  weather ............ utf-8 · fri jun 12 [21:42:08]
      -- Weather comes from the dashboard's own cached wx fetch.
      local ok, kanagawa = pcall(function()
        return require("kanagawa.colors").setup({ theme = "wave" }).palette
      end)
      local p = ok and kanagawa or {}
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

      -- ── transient cmdline-replacement components ──────────────────────────
      -- These three recover what the cmdline used to show now that cmdheight=0:

      -- (1) search match count. After you press n/N or *, # the count normally
      -- echoes to the (now absent) cmdline; searchcount() recovers "[3/12]".
      -- Refreshes on CursorMoved (n/N/*/# all move the cursor), so no extra glue.
      local searchcount = {
        function()
          local sc = vim.fn.searchcount({ maxcount = 999 })
          if not sc.total or sc.total == 0 then
            return ""
          end
          if sc.incomplete == 1 then -- recompute timed out
            return "[?/?]"
          end
          return string.format("[%d/%d]", sc.current, sc.total)
        end,
        cond = function()
          return vim.v.hlsearch == 1
        end,
        icon = "",
        color = { fg = p.carpYellow },
      }

      -- (2) macro recording indicator. reg_recording() is "" unless recording.
      local recording = {
        function()
          return "REC @" .. vim.fn.reg_recording()
        end,
        cond = function()
          return vim.fn.reg_recording() ~= ""
        end,
        color = { fg = p.samuraiRed, gui = "bold" },
      }

      -- (3) active LSP clients attached to the current buffer.
      local lsp = {
        function()
          local clients = vim.lsp.get_clients({ bufnr = 0 })
          local names = {}
          for _, c in ipairs(clients) do
            names[#names + 1] = c.name
          end
          return table.concat(names, " ")
        end,
        cond = function()
          return #vim.lsp.get_clients({ bufnr = 0 }) > 0
        end,
        icon = "",
        color = { fg = p.springGreen },
      }

      -- FRAGILE SEAM: lualine does not redraw the statusline when a macro
      -- recording starts/stops, so the REC indicator would lag up to the refresh
      -- interval. Force an immediate refresh. RecordingLeave fires while
      -- reg_recording() is STILL set, so defer one tick to read the cleared
      -- value. Delete this block if a future nvim redraws on these events.
      local rec_group = vim.api.nvim_create_augroup("LualineRecording", { clear = true })
      vim.api.nvim_create_autocmd("RecordingEnter", {
        group = rec_group,
        callback = function()
          require("lualine").refresh()
        end,
      })
      vim.api.nvim_create_autocmd("RecordingLeave", {
        group = rec_group,
        callback = function()
          vim.defer_fn(function()
            require("lualine").refresh()
          end, 50)
        end,
      })

      return {
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
          lualine_c = {
            { "filename", path = 1 },
            recording,
            searchcount,
            -- showcmd / pending operators, routed here by showcmdloc=statusline.
            "%S",
          },
          lualine_x = {
            -- "encoding",
            -- "fileformat",
            lsp,
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
