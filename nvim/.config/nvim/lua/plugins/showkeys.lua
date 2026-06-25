return {
  "nvzone/showkeys",
  cmd = "ShowkeysToggle",
  keys = {
    { "<leader>K", "<cmd>ShowkeysToggle<CR>", desc = "Toggle showkeys" },
  },
  opts = {
    timeout = 3,
    maxkeys = 8,
    position = "bottom-center",
  },
}
