-- nvim-dap: core Debug Adapter Protocol client.
--
-- Docs once installed:
--   :help dap.txt
--   :help dap-adapter
--   :help dap-configuration
--   :help dap-api
--   :help dapui
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
    "DapToggleFalseBreakpoint",
  },
  keys = {
    {
      "<leader>df",
      function()
        vim.cmd("DapToggleFalseBreakpoint")
      end,
      desc = "Debug false breakpoint toggle",
    },
    {
      "<leader>dw",
      function()
        vim.cmd("DapAddWatch")
      end,
      desc = "Add debug watch under cursor",
    },
  },
  dependencies = {
    "tpope/vim-repeat",
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()

    vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#fb4934" })
    vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#fabd2f" })
    vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#83a598" })
    vim.api.nvim_set_hl(0, "DapStopped", { fg = "#b8bb26" })
    vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#928374" })
    vim.api.nvim_set_hl(0, "DapBreakpointDisabled", { fg = "#928374" })

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
    vim.fn.sign_define("DapBreakpointDisabled", {
      text = "○",
      texthl = "DapBreakpointDisabled",
      numhl = "DapBreakpointDisabled",
    })

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
      {
        type = "debugpy",
        request = "launch",
        name = "Launch madden-agent uvicorn",
        module = "uvicorn",
        args = {
          "src.server:app",
          "--host",
          "127.0.0.1",
          "--port",
          "8000",
          "--log-level",
          "debug",
        },
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        justMyCode = false,
        pythonPath = project_python,
      },

      {
        type = "debugpy",
        request = "attach",
        name = "Attach madden-agent debugpy :5678",
        connect = {
          host = "127.0.0.1",
          port = 5678,
        },
        cwd = "${workspaceFolder}",
        justMyCode = false,
      },
    }

    local function open_debug_ui(args)
      local ok, err = pcall(dapui.open, args)
      if ok then
        -- nvim-dap listener contract: returning boolean true unregisters the
        -- listener. Keep this nil so dap-ui opens for every future session.
        return
      end

      -- nvim-dap-ui keeps split window ids internally. If one dap-ui window is
      -- closed manually, a later `open()` can try to resize a stale id and raise
      -- "Invalid window id". Closing resets dap-ui's layout state, then retry.
      pcall(dapui.close)
      ok, err = pcall(dapui.open, args)
      if not ok then
        vim.notify(("nvim-dap-ui failed to open: %s"):format(err), vim.log.levels.ERROR)
      end
    end

    local function close_debug_ui()
      pcall(dapui.close)
    end

    local function is_leetcode_debug_session(session)
      local config = session and session.config
      local name = config and config.name
      local program = config and config.program
      local leetcode_debug_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "leetcode", "debug")

      return type(name) == "string"
          and vim.startswith(name, "LeetCode: ")
          and type(program) == "string"
          and vim.startswith(vim.fs.normalize(program), vim.fs.normalize(leetcode_debug_dir) .. "/")
    end

    local function close_non_leetcode_debug_ui(session)
      if not is_leetcode_debug_session(session) then
        close_debug_ui()
      end
    end

    local function current_debug_expression()
      local mode = vim.fn.mode()
      if mode == "v" or mode == "V" or mode == "\022" then
        local lines = require("dapui.util").get_selection(vim.fn.getpos("v"), vim.fn.getpos("."))
        return lines and table.concat(lines, "\n") or ""
      end

      return vim.fn.expand("<cexpr>")
    end

    local function add_debug_watch(expr)
      if expr == nil or expr == "" then
        expr = current_debug_expression()
      end
      expr = vim.trim(expr or "")
      if expr == "" then
        expr = vim.fn.input("Watch expression: ")
      end
      if expr == nil or vim.trim(expr) == "" then
        return
      end

      -- `watches.add()` is dap-ui's public watch API. Use table indexing to
      -- keep lua-language-server quiet across dap-ui annotation versions.
      dapui["elements"]["watches"].add(expr)
      open_debug_ui()
    end

    vim.api.nvim_create_user_command("DapAddWatch", function(opts)
      add_debug_watch(opts.args)
    end, {
      nargs = "*",
      desc = "Add an nvim-dap-ui watch expression",
    })

    local function debug_hover()
      dapui.eval(nil, { enter = true })
    end

    local function open_debug_watches()
      dapui.float_element("watches", { enter = true })
    end

    local function open_debug_repl()
      dapui.float_element("repl", { enter = true })
    end

    local breakpoint_sign_group = "dap_breakpoints"

    local function breakpoint_condition_is_false(bp)
      local condition = bp and bp.condition
      return type(condition) == "string" and vim.trim(condition):lower() == "false"
    end

    local function breakpoint_sign_name(bp)
      if bp.state and bp.state.verified == false then
        return "DapBreakpointRejected"
      end
      if breakpoint_condition_is_false(bp) then
        return "DapBreakpointDisabled"
      end
      if type(bp.condition) == "string" and vim.trim(bp.condition) ~= "" then
        return "DapBreakpointCondition"
      end
      if type(bp.logMessage) == "string" and vim.trim(bp.logMessage) ~= "" then
        return "DapLogPoint"
      end
      return "DapBreakpoint"
    end

    local function refresh_breakpoint_signs(bufnr)
      local ok, breakpoints = pcall(require("dap.breakpoints").get, bufnr)
      if not ok then
        return
      end

      for buf, bps in pairs(breakpoints) do
        if vim.api.nvim_buf_is_valid(buf) then
          local placed_ok, placed = pcall(vim.fn.sign_getplaced, buf, { group = breakpoint_sign_group })
          local signs = placed_ok and placed[1] and placed[1].signs or {}
          local signs_by_line = {}

          for _, sign in ipairs(signs) do
            signs_by_line[sign.lnum] = signs_by_line[sign.lnum] or {}
            table.insert(signs_by_line[sign.lnum], sign)
          end

          for _, bp in ipairs(bps) do
            for _, sign in ipairs(signs_by_line[bp.line] or {}) do
              vim.fn.sign_place(sign.id, breakpoint_sign_group, breakpoint_sign_name(bp), buf, {
                lnum = bp.line,
                priority = 21,
              })
            end
          end
        end
      end
    end

    local function current_line_breakpoint()
      local bufnr = vim.api.nvim_get_current_buf()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local breakpoints = require("dap.breakpoints").get(bufnr)[bufnr] or {}

      for _, bp in ipairs(breakpoints) do
        if bp.line == lnum then
          return bp
        end
      end
    end

    local function toggle_false_breakpoint()
      if breakpoint_condition_is_false(current_line_breakpoint()) then
        dap.set_breakpoint()
      else
        dap.set_breakpoint("false")
      end
      refresh_breakpoint_signs(vim.api.nvim_get_current_buf())
    end

    vim.api.nvim_create_user_command("DapToggleFalseBreakpoint", toggle_false_breakpoint, {
      desc = "Toggle a disabled breakpoint via condition=false",
    })

    local function refresh_all_breakpoint_signs()
      refresh_breakpoint_signs()
    end

    dap.listeners.after.event_initialized["user_disabled_breakpoint_signs"] = function()
      vim.defer_fn(refresh_all_breakpoint_signs, 100)
    end
    dap.listeners.after.event_stopped["user_disabled_breakpoint_signs"] = refresh_all_breakpoint_signs

    ---@type { mode: string, lhs: string, rhs: function, desc: string }[]
    local debug_keymaps = {
      { mode = "n", lhs = "<C-S-l>",      rhs = dap.step_over,      desc = "Debug step over" },
      { mode = "n", lhs = "<C-S-j>",      rhs = dap.step_into,      desc = "Debug step into" },
      { mode = "n", lhs = "<C-S-k>",      rhs = dap.step_out,       desc = "Debug step out" },
      { mode = "n", lhs = "<leader>do", rhs = dap.step_over,      desc = "Debug step over" },
      { mode = "n", lhs = "<leader>di", rhs = dap.step_into,      desc = "Debug step into" },
      { mode = "n", lhs = "<leader>du", rhs = dap.step_out,       desc = "Debug step out" },
      { mode = "n", lhs = "<leader>dt", rhs = dap.terminate,      desc = "Debug terminate" },
      { mode = "n", lhs = "<leader>dR", rhs = open_debug_repl,    desc = "Debug REPL" },
      { mode = "n", lhs = "<leader>dC", rhs = close_debug_ui,     desc = "Close debug UI and terminal" },
      { mode = "n", lhs = "<leader>dw", rhs = add_debug_watch,    desc = "Add debug watch under cursor" },
      { mode = "x", lhs = "<leader>dw", rhs = add_debug_watch,    desc = "Add selected debug watch" },
      { mode = "n", lhs = "<leader>dh", rhs = debug_hover,        desc = "Debug hover" },
      { mode = "x", lhs = "<leader>dh", rhs = debug_hover,        desc = "Debug hover" },
      { mode = "n", lhs = "<leader>dW", rhs = open_debug_watches, desc = "Open debug watches" },
      { mode = "n", lhs = "<leader>dF", rhs = toggle_false_breakpoint, desc = "Debug false breakpoint toggle" },
      {
        mode = "n",
        lhs = "<leader>dv",
        rhs = function()
          local ok = pcall(dapui.toggle)
          if not ok then
            pcall(dapui.close)
            open_debug_ui()
          end
        end,
        desc = "Debug UI toggle",
      },
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

    local function restore_non_leetcode_debug_keymaps(session)
      if not is_leetcode_debug_session(session) then
        restore_debug_keymaps()
      end
    end

    local function close_leetcode_debug_ui_on_session_end(old_session, new_session)
      -- :help dap-listeners-on_session: this fires for new sessions, focus
      -- changes, and when the last remaining session finishes. Use that final
      -- no-new-session transition for LeetDebug cleanup so there is no delayed
      -- timer from a previous run that can close the next run's freshly-opened
      -- dap-ui windows.
      if new_session == nil and is_leetcode_debug_session(old_session) then
        close_debug_ui()
        restore_debug_keymaps()
      end
    end

    dap.listeners.before.attach["user_dapui"] = open_debug_ui
    dap.listeners.before.launch["user_dapui"] = open_debug_ui
    dap.listeners.before.event_terminated["user_dapui"] = close_non_leetcode_debug_ui
    dap.listeners.before.event_exited["user_dapui"] = close_non_leetcode_debug_ui
    dap.listeners.on_session["user_leetcode_debug_dapui"] = close_leetcode_debug_ui_on_session_end

    dap.listeners.after.event_initialized["user_debug_keymaps"] = save_and_set_debug_keymaps
    dap.listeners.before.event_terminated["user_debug_keymaps"] = restore_non_leetcode_debug_keymaps
    dap.listeners.before.event_exited["user_debug_keymaps"] = restore_non_leetcode_debug_keymaps

    require("config.dap_breakpoints").setup()
  end,
}
