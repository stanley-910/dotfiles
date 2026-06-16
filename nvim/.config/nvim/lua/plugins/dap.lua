-- nvim-dap: core Debug Adapter Protocol client.
--
-- Docs once installed:
--   :help dap.txt
--   :help dap-adapter
--   :help dap-configuration
--   :help dap-api
--   :help dap-view
return {
  "mfussenegger/nvim-dap",
  lazy = true,
  cmd = {
    "DapBreakpointsClearSaved",
    "DapBreakpointsLoad",
    "DapBreakpointsSave",
    "DapContinue",
    "DapRestartFrame",
    "DapSetLogLevel",
    "DapShowLog",
    "DapStepInto",
    "DapStepOut",
    "DapStepOver",
    "DapTerminate",
    "DapToggleBreakpoint",
  },
  dependencies = {
    "tpope/vim-repeat",
    {
      "igorlfs/nvim-dap-view",
      ---@module 'dap-view'
      ---@type dapview.Config
      opts = {
        winbar = {
          -- Put the watch list first because it is the highest-signal view while
          -- stepping through small scripts and experiments.
          default_section = "watches",
          controls = {
            enabled = true,
            position = "right",
          },
        },
        windows = {
          size = 0.25,
          position = "below",
          terminal = {
            size = 0.35,
            position = "right",
          },
        },
        keymaps = {
          base = {
            next_view = "<Tab>",
            prev_view = "<S-Tab>",
          },
        },
        virtual_text = {
          enabled = true,
          position = "eol",
        },
        -- Open the UI with a debug session and close it when the last session
        -- exits, while preserving terminal output for post-run inspection.
        auto_toggle = "keep_terminal",
      },
    },
  },
  config = function()
    local dap = require("dap")

    vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#fb4934" })
    vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#fabd2f" })
    vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#83a598" })
    vim.api.nvim_set_hl(0, "DapStopped", { fg = "#b8bb26" })
    vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#928374" })

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", numhl = "DapBreakpoint" })
    vim.fn.sign_define("DapBreakpointCondition", {
      text = "◆",
      texthl = "DapBreakpointCondition",
      numhl = "DapBreakpointCondition",
    })
    vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint", numhl = "DapLogPoint" })
    vim.fn.sign_define("DapStopped", { text = "→", texthl = "DapStopped", numhl = "DapStopped" })
    vim.fn.sign_define("DapBreakpointRejected", {
      text = "○",
      texthl = "DapBreakpointRejected",
      numhl = "DapBreakpointRejected",
    })

    -- DAP's default switchbuf can steal focus into the dap-view terminal split
    -- when the terminal is on the right. Prefer visible/source windows first.
    dap.defaults.fallback.switchbuf = "usevisible,usetab,newtab"

    local function first_executable(names)
      for _, name in ipairs(names) do
        local path = vim.fn.exepath(name)
        if path ~= "" then
          return path
        end
      end
    end

    local function project_python()
      local venv = vim.env.VIRTUAL_ENV
      if venv and vim.uv.fs_stat(venv .. "/bin/python") then
        return venv .. "/bin/python"
      end

      for _, name in ipairs({ ".venv", "venv" }) do
        local dir = vim.fs.find(name, { path = vim.fn.getcwd(), upward = true, type = "directory" })[1]
        local python = dir and (dir .. "/bin/python")
        if python and vim.uv.fs_stat(python) then
          return python
        end
      end

      return first_executable({ "python3", "python" }) or "python3"
    end

    -- Adapter Python needs the debugpy module; prefer Mason's debugpy venv when
    -- installed, but keep the debuggee interpreter project-local via pythonPath.
    local mason_debugpy_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
    local adapter_python = vim.uv.fs_stat(mason_debugpy_python) and mason_debugpy_python
        or first_executable({ "python3", "python" })
        or "python3"

    dap.adapters.debugpy = {
      type = "executable",
      command = adapter_python,
      args = { "-m", "debugpy.adapter" },
    }

    dap.configurations.python = {
      {
        type = "debugpy",
        request = "launch",
        name = "Launch current file",
        program = "${file}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        justMyCode = true,
        pythonPath = project_python,
      },
    }

    local function close_debug_ui()
      require("dap-view").close(true)
    end

    local function add_debug_watch()
      require("dap-view").add_expr()
    end

    local function debug_hover()
      require("dap-view").hover(nil, true)
    end

    local function open_debug_watches()
      require("dap-view").jump_to_view("watches")
    end

    ---@type { mode: string, lhs: string, rhs: function, desc: string }[]
    local debug_keymaps = {
      { mode = "n", lhs = "<M-l>", rhs = dap.step_over, desc = "Debug step over" },
      { mode = "n", lhs = "<M-j>", rhs = dap.step_into, desc = "Debug step into" },
      { mode = "n", lhs = "<M-k>", rhs = dap.step_out, desc = "Debug step out" },
      { mode = "n", lhs = "<leader>do", rhs = dap.step_over, desc = "Debug step over" },
      { mode = "n", lhs = "<leader>di", rhs = dap.step_into, desc = "Debug step into" },
      { mode = "n", lhs = "<leader>du", rhs = dap.step_out, desc = "Debug step out" },
      { mode = "n", lhs = "<leader>dt", rhs = dap.terminate, desc = "Debug terminate" },
      { mode = "n", lhs = "<leader>dR", rhs = dap.repl.open, desc = "Debug REPL" },
      { mode = "n", lhs = "<leader>dC", rhs = close_debug_ui, desc = "Close debug UI and terminal" },
      { mode = "n", lhs = "<leader>dw", rhs = add_debug_watch, desc = "Add debug watch" },
      { mode = "x", lhs = "<leader>dw", rhs = add_debug_watch, desc = "Add debug watch" },
      { mode = "n", lhs = "<leader>dh", rhs = debug_hover, desc = "Debug hover" },
      { mode = "x", lhs = "<leader>dh", rhs = debug_hover, desc = "Debug hover" },
      { mode = "n", lhs = "<leader>dW", rhs = open_debug_watches, desc = "Open debug watches" },
    }
    ---@type table<string, table|false>
    local saved_keymaps = {}

    local function save_and_set_debug_keymaps()
      if next(saved_keymaps) ~= nil then
        return
      end

      for _, keymap in ipairs(debug_keymaps) do
        local existing = vim.fn.maparg(keymap.lhs, keymap.mode, false, true)
        local has_existing = type(existing) == "table" and next(existing) ~= nil
        saved_keymaps[keymap.mode .. keymap.lhs] = has_existing and existing or false
        vim.keymap.set(keymap.mode, keymap.lhs, keymap.rhs, { silent = true, desc = keymap.desc })
      end
    end

    local function restore_debug_keymaps()
      for _, keymap in ipairs(debug_keymaps) do
        local saved = saved_keymaps[keymap.mode .. keymap.lhs]
        pcall(vim.keymap.del, keymap.mode, keymap.lhs)

        if type(saved) == "table" then
          vim.fn.mapset(keymap.mode, false, saved)
        end
      end
      saved_keymaps = {}
    end

    dap.listeners.after.event_initialized["user_debug_keymaps"] = save_and_set_debug_keymaps
    dap.listeners.before.event_terminated["user_debug_keymaps"] = restore_debug_keymaps
    dap.listeners.before.event_exited["user_debug_keymaps"] = restore_debug_keymaps

    require("config.dap_breakpoints").setup()
  end,
}
