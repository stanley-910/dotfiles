-- ~/.config/nvim/lua/plugins/telescope.lua
-- Telescope: Fuzzy finder for files, text, and more
--
return {
  'nvim-telescope/telescope.nvim',
  version = '*',

  -- Keymaps live in lua/config/keymap.lua so editor muscle-memory mappings are centralized.

  config = function()
    local telescope = require('telescope')
    local actions = require('telescope.actions')
    local layout_actions = require('telescope.actions.layout')

    telescope.setup({
      defaults = {
        preview = {
          hide_on_startup = false           -- Always show file preview panel
        },
        mappings = {
          -- Insert mode mappings (when typing in search)
          i = {
            ["<C-j>"] = actions.move_selection_next,                                   -- Move down in results
            ["<C-k>"] = actions.move_selection_previous,                               -- Move up in results
            ["<C-s>"] = actions.select_default,                                        -- Open focused result
            ['<C-p>'] = layout_actions.toggle_preview                                  -- Toggle preview panel
          },
          -- Normal mode mappings (press ESC to enter)
          n = {
            ["<C-s>"] = actions.select_default,                                        -- Open focused result
          },
        },
      },

      pickers = {
        live_grep = {
          -- file_ignore_patterns = { 'node_modules', '.git', '.venv' },
          additional_args = function(_)
            return { "--hidden",
              "--glob", "!**/.git/*",
              "--glob", "!**/node_modules/*",
              "--glob", "!**/.venv/*",
            }
          end
        },
        find_files = {
          -- file_ignore_patterns = { 'node_modules', '.git', '.venv' },
          hidden = true,
          -- Use fd instead of default find command
          find_command = {
            'fd',                        -- Fast file finder (written in Rust)
            '--type', 'f',               -- Only find files (not directories)
            '--color=never',             -- Disable color output
            '--follow',                  -- Follow symbolic links
            '-E', '.git/*'               -- Exclude .git directory
          },
        },
      },
    })

    -- Load fzf extension for faster fuzzy finding
    pcall(telescope.load_extension, 'fzf')
  end,

  dependencies = {
    'nvim-lua/plenary.nvim',     -- Required: core utilities
    -- Optional but highly recommended for performance
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  }
}
