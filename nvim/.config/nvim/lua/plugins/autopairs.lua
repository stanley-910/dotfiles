return {
  'windwp/nvim-autopairs',
  event = "InsertEnter",
  opts = {
    -- typr is a typing-practice plugin; auto-inserting closing quotes/brackets
    -- registers as typos, so disable autopairs in its buffer.
    disable_filetype = { "TelescopePrompt", "spectre_panel", "snacks_picker_input", "typr" },
  },
}
