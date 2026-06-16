return {
  "nvzone/showkeys",
  cmd = "ShowkeysToggle",
  keys = {
    { "<leader>K", "<cmd>ShowkeysToggle<CR>", desc = "Toggle showkeys" },
  },
  opts = {
    timeout = 3,
    maxkeys = 5,
    position = "bottom-right",
  },
}
