return {
    'nvim-telescope/telescope.nvim', version = '*',

    -- Lazy.nvim keys for opening telescope pickers
    keys = { 
        {"<leader>/", "<cmd>Telescope live_grep<CR>", desc = "Live Grep"},
        {"<leader><leader>", "<cmd>Telescope find_files<CR>", desc = "Find Files"},
    },

    -- Configure telescope
    config = function()
        local telescope = require('telescope')
        local actions = require('telescope.actions')
        
        telescope.setup({
            defaults = {
		    preview = {
			    hide_on_startup = false
		    },
                mappings = {
                    -- Insert mode mappings
                    i = {
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-k>"] = actions.move_selection_previous,
			['<C-p>'] = require('telescope.actions.layout').toggle_preview
                    },
                    -- Normal mode mappings
                    n = {
                    },
                },
            },
        })
        
        -- Load fzf extension if available
        pcall(telescope.load_extension, 'fzf')
    end,

    dependencies = {
        'nvim-lua/plenary.nvim',
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    }
}
