return {
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      win_options = {
        signcolumn = "yes:2",
      },
      view_options = {
        show_hidden = true,
        -- always hide previous dir entry
        is_always_hidden = function(name, bufnr)
          return name == ".."
        end,
      },
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      keymaps = {
        -- Navigate to git root marker
        ["gh"] = {
          callback = function()
            local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))

            -- Debug: show what we got
            vim.notify("Git root: " .. git_root, vim.log.levels.INFO)
            -- vim.notify("Shell error: " .. vim.v.shell_error, vim.log.levels.INFO)

            if vim.v.shell_error ~= 0 then
              vim.notify("Not in a git repository", vim.log.levels.WARN)
              return
            end

            require("oil").open(git_root)
          end,
          desc = "Go to git root",
          mode = "n",
        },
      },
    },
    -- Optional dependency for file icons. The central mini.icons spec also
    -- provides the compatibility shim some icon consumers still expect.
    dependencies = { "nvim-mini/mini.icons" },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
  },
  {
    "refractalize/oil-git-status.nvim",

    dependencies = {
      "stevearc/oil.nvim",
    },

    config = true,
  },
}
