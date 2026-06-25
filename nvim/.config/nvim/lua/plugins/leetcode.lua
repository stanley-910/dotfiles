-- ~/.config/nvim/lua/plugins/leetcode.lua
-- leetcode.nvim: solve LeetCode problems inside Neovim.
-- Full option types: https://github.com/kawre/leetcode.nvim/blob/master/lua/leetcode/config/template.lua
--
-- Launch maps live in the lazy `keys` table below (the trouble.nvim pattern in
-- this config), so the plugin lazy-loads on first use. In-question keys (q,
-- <Esc>, <CR>, r, U, H, L) are buffer-local inside leetcode windows, so they do
-- not collide with the global maps in lua/config/keymap.lua.
local function install_menu_key_overrides()
  local function open_dashboard()
    require("leetcode").stop()

    -- leetcode.nvim tears down its tab/buffer on schedule. Wait a tick before
    -- opening Snacks.dashboard so the dashboard does not get opened in a window
    -- that leetcode is about to close.
    vim.defer_fn(function()
      require("config.dashboard").open()
    end, 75)
  end

  -- leetcode.nvim hard-codes the dashboard Back button shortcut as `q` in
  -- leetcode-ui.lines.button.menu.back. Override only that tiny module so
  -- submenu pages display and use <Esc> for Back.
  package.loaded["leetcode-ui.lines.button.menu.back"] = nil
  package.preload["leetcode-ui.lines.button.menu.back"] = function()
    local MenuButton = require("leetcode-ui.lines.button.menu")
    local cmd = require("leetcode.command")

    local MenuBackButton = MenuButton:extend("LeetMenuBackButton")

    function MenuBackButton:init(page)
      MenuBackButton.super.init(self, "Back", {
        icon = "",
        sc = "<Esc>",
        on_press = function()
          cmd.set_menu_page(page)
        end,
      })
    end

    return MenuBackButton
  end

  -- The top-level LeetCode menu has no Back button. Track the current menu page
  -- and map <Esc> on that home page to leave LeetCode and show the real Neovim
  -- dashboard. This avoids copying leetcode-ui.group.page.menu wholesale.
  local function patch_menu_renderer(Menu)
    if Menu.__stanley_esc_dashboard then
      return Menu
    end

    local set_page = Menu.set_page
    local draw = Menu.draw

    function Menu:set_page(name)
      self.__stanley_page = name
      return set_page(self, name)
    end

    function Menu:draw(...)
      local result = draw(self, ...)
      if self.__stanley_page == "menu" then
        self:map("n", "<Esc>", open_dashboard, {
          noremap = false,
          silent = true,
          nowait = true,
          clearable = true,
        })
      end
      return result
    end

    Menu.__stanley_esc_dashboard = true
    return Menu
  end

  local menu_module = "leetcode-ui.renderer.menu"
  if type(package.loaded[menu_module]) == "table" then
    patch_menu_renderer(package.loaded[menu_module])
  else
    package.loaded[menu_module] = nil
    package.preload[menu_module] = function()
      local menu_path = vim.api.nvim_get_runtime_file("lua/leetcode-ui/renderer/menu.lua", false)[1]
      assert(menu_path, "Could not find leetcode.nvim menu renderer")
      local chunk = assert(loadfile(menu_path))
      return patch_menu_renderer(chunk())
    end
  end
end

local function write_file_if_missing(path, lines)
  if vim.uv.fs_stat(path) then
    return
  end

  vim.fn.writefile(lines, path)
end

local function ensure_tool_configs(opts)
  -- leetcode.nvim writes problem files under storage.home. Seed tool-native
  -- project configs there so basedpyright/ruff treat generated LeetCode files
  -- as contest scratch files, while real Python projects keep their own rules.
  -- Only create missing files; manual edits in the LeetCode workspace win.
  local storage = opts.storage or {}
  local home = vim.fn.expand(storage.home or vim.fs.joinpath(vim.fn.stdpath("data"), "leetcode"))

  vim.fn.mkdir(home, "p")

  write_file_if_missing(vim.fs.joinpath(home, "pyrightconfig.json"), {
    "{",
    '  "typeCheckingMode": "off",',
    '  "reportUnusedImport": "none",',
    '  "reportUnusedParameter": "none",',
    '  "reportWildcardImportFromLibrary": "none",',
    '  "reportReturnType": "none",',
    '  "reportDeprecated": "none"',
    "}",
  })

  write_file_if_missing(vim.fs.joinpath(home, "ruff.toml"), {
    "[lint]",
    'ignore = ["F401", "F403", "F405"]',
  })
end

return {
  "kawre/leetcode.nvim",

  -- Lazy-load on :Leet and the local :LeetDebug helper. NOTE: choosing
  -- cmd-based loading disables the alternative `arg` launch method (opening
  -- nvim with `nvim leetcode.nvim`).
  cmd = { "Leet", "LeetDebug" },

  -- The question description is formatted with the tree-sitter-html parser.
  -- nvim-treesitter here is on the `main` branch, where :TSUpdate only refreshes
  -- already-installed parsers, so use :TSInstall to guarantee html is present.
  build = ":TSInstall html",

  dependencies = {
    "nvim-lua/plenary.nvim", -- required: core utilities
    "MunifTanjim/nui.nvim",  -- required: UI components
    "folke/snacks.nvim",     -- picker provider
    "nvim-tree/nvim-web-devicons"
  },

  ---@type lc.UserConfig
  opts = {
    -- Solving language. Switch per-question at runtime with :Leet lang.
    lang = "python3",

    -- Reuse the existing Snacks picker install for problem/tab/lang pickers.
    picker = { provider = "snacks-picker" },

    -- Make Escape act like the plugin's close/back key in popups and splits.
    keys = { toggle = { "q", "<Esc>" } },

    -- Standalone mode (the default) wants to own the whole Neovim session and
    -- refuses to start when listed buffers exist ("contains listed buffers").
    -- We launch :Leet mid-session via keymaps, so run non-standalone. Exit the
    -- dashboard with :Leet exit.
    plugins = { non_standalone = true },

    -- Everything below is the plugin's own sensible default, kept explicit so
    -- it is easy to tweak later:
    --   editor.reset_previous_code = true   -- reset code when switching questions
    --   editor.fold_imports        = true   -- fold the injected imports block
    --   console.open_on_runcode    = true   -- pop the console open on :Leet run
    --   description.position        = "left"
    --   image_support               = false  -- needs 3rd/image.nvim; renders text otherwise

    -- Per-language code injection (imports / boilerplate). Uncomment to use:
    -- injector = {
    --   ["python3"] = {
    --     before = { "from typing import List, Optional" },
    --   },
    -- },
  },

  config = function(_, opts)
    install_menu_key_overrides()
    ensure_tool_configs(opts)
    require("leetcode").setup(opts)
    require("config.leetcode_debug").setup()
  end,

  -- <leader>p = plugins group, l = leetcode. Descriptions surface in which-key.
  -- NOTE: the dashboard map is bare `:Leet`. leetcode registers `:Leet` in two
  -- stages: a no-arg bootstrap command that opens the dashboard, which then
  -- swaps in the real `nargs="?"` command. Subcommands (menu/run/submit/...)
  -- only exist *after* the dashboard has opened once, so the launch map must be
  -- bare `:Leet` or it throws E488. The rest are used inside an open question.
  keys = {
    { "<leader>pll", "<cmd>Leet<cr>",         desc = "LeetCode: dashboard" },
    { "<leader>plr", "<cmd>Leet run<cr>",     desc = "LeetCode: run" },
    { "<leader>pls", "<cmd>Leet submit<cr>",  desc = "LeetCode: submit" },
    { "<leader>plc", "<cmd>Leet console<cr>", desc = "LeetCode: console" },
    { "<leader>pld", "<cmd>Leet daily<cr>",   desc = "LeetCode: daily question" },
    { "<leader>plD", "<cmd>LeetDebug<cr>",    desc = "LeetCode: debug tests" },
    { "<leader>plL", "<cmd>Leet lang<cr>",    desc = "LeetCode: switch language" },
  },
}
