-- diffview+ use cases to remember:
--   <leader>gv  Review the whole working tree when Snacks' hunk picker is too small.
--   <leader>gV  Review exactly what is staged before committing.
--   <leader>gF  Inspect the current file's patch history.
--   <leader>gY  Compare old versions of the current file against your local copy.
--   g<C-x>      Cycle layouts; try diff1_inline for GitHub-style unified diffs.
--   w / C       In the file panel: select multiple files / clear selection, then stage/restore as a batch.
--   :DiffviewMergeFiles and :DiffviewDiffDirs are for non-Git file/dir diffs or external merge tools.
return {
  "dlyongemallo/diffview-plus.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewFileHistory",
    "DiffviewFocusFiles",
    "DiffviewToggleFiles",
    "DiffviewRefresh",
    "DiffviewMergeFiles",
    "DiffviewDiffDirs",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    -- Snacks owns the existing <leader>g picker/lazygit/gitbrowse maps; keep
    -- Diffview on still-free mnemonics for full-tab review flows.
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Git diff view" },
    { "<leader>gV", "<cmd>DiffviewOpen --cached<cr>", desc = "Git staged diff view" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git branch history" },
    { "<leader>gF", "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
    { "<leader>gY", "<cmd>DiffviewFileHistory --pin-local %<cr>", desc = "Git file history vs local" },
  },
  opts = {
    enhanced_diff_hl = true,
    use_icons = true,
    show_help_hints = true,
    watch_index = true,
    restore_session = true,

    view = {
      default = {
        layout = "diff2_horizontal",
        disable_diagnostics = false,
        winbar_info = false,
      },
      merge_tool = {
        layout = "diff3_horizontal",
        disable_diagnostics = true,
        winbar_info = true,
      },
      file_history = {
        layout = "diff2_horizontal",
        disable_diagnostics = false,
        winbar_info = false,
        pin_local = false,
      },
      inline = {
        style = "unified",
      },
      cycle_layouts = {
        default = { "diff2_horizontal", "diff2_vertical", "diff1_inline" },
        merge_tool = { "diff3_horizontal", "diff3_vertical", "diff3_mixed", "diff4_mixed", "diff1_plain" },
      },
    },

    file_panel = {
      listing_style = "tree",
      tree_options = {
        flatten_dirs = true,
        folder_statuses = "only_folded",
      },
      win_config = {
        position = "left",
        width = 35,
      },
    },
  },
}
