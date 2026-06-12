return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 0, -- Set delay to 500ms (or any integer in milliseconds)
        -- other options...
      },
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            silent = true,
            desc = desc,
          })
        end

        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]h", bang = true })
            return
          end

          gitsigns.nav_hunk("next")
        end, "Next git hunk")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[h", bang = true })
            return
          end

          gitsigns.nav_hunk("prev")
        end, "Previous git hunk")

        map("n", "<leader>hs", gitsigns.stage_hunk, "Stage git hunk")
        map("n", "<leader>hr", gitsigns.reset_hunk, "Reset git hunk")
        map("n", "<leader>hp", gitsigns.preview_hunk, "Preview git hunk")
        map("n", "<leader>hb", function()
          gitsigns.blame_line({ full = true })
        end, "Blame current line")
        map("n", "<leader>hB", gitsigns.toggle_current_line_blame, "Toggle line blame")
        map("n", "<leader>hd", gitsigns.diffthis, "Diff current file")
        map("n", "<leader>hD", function()
          gitsigns.diffthis("~")
        end, "Diff current file against HEAD~")
        map("n", "<leader>hQ", gitsigns.setqflist, "Git hunks to quickfix")
        map("n", "<leader>ht", gitsigns.toggle_deleted, "Toggle deleted lines")

        map("v", "<leader>hs", function()
          gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selected git hunk")
        map("v", "<leader>hr", function()
          gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected git hunk")

        map({ "o", "x" }, "ih", gitsigns.select_hunk, "Select git hunk")
      end,
    },
  },
}
