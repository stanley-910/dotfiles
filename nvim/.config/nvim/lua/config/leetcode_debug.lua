-- Local Python debugger harness for leetcode.nvim questions.
--
-- Fragility note: leetcode.nvim does not expose a public debug API. This module
-- intentionally keeps the internal touch points small: curr_question(), the
-- current question metadata, and the console testcase content used by :Leet run.

local M = {}

local debug_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "leetcode", "debug")

-- nvim-dap serializes launch config into the adapter request, so LeetDebug-only
-- behavior cannot live in dap.run({ ... }) fields. Keep source-jump behavior in
-- dap.defaults.debugpy.switchbuf instead, and restore it when each generated
-- harness session ends.
local switchbuf_state = {
  debugpy_base = nil,
  debugpy_stack = {},
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "LeetCode Debug" })
end

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

local function value_or(value, fallback)
  if value == nil or value == vim.NIL or value == "" then
    return fallback
  end

  return value
end

local function sanitize_filename(value)
  value = tostring(value_or(value, "leetcode"))
  value = value:gsub("[^%w_.-]", "_")
  return value ~= "" and value or "leetcode"
end

local function write_text(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local lines = vim.split(text, "\n", { plain = true })

  if lines[#lines] == "" then
    table.remove(lines)
  end

  vim.fn.writefile(lines, path)
end

local function question_file(question)
  if question.file and type(question.file.absolute) == "function" then
    return question.file:absolute()
  end

  if question.bufnr and vim.api.nvim_buf_is_valid(question.bufnr) then
    local name = vim.api.nvim_buf_get_name(question.bufnr)
    if name ~= "" then
      return name
    end
  end
end

local function question_source(question, path)
  if question.bufnr and vim.api.nvim_buf_is_valid(question.bufnr) then
    local lines = vim.api.nvim_buf_get_lines(question.bufnr, 0, -1, false)
    return table.concat(lines, "\n") .. "\n"
  end

  local lines = vim.fn.readfile(path)
  return table.concat(lines, "\n") .. "\n"
end

local function testcase_content(question)
  local testcase = question.console and question.console.testcase
  if testcase and type(testcase.content) == "function" then
    return testcase:content()
  end

  return ""
end

local function metadata_params(question)
  local metadata = value_or(question.q and question.q.meta_data, {})
  local params = metadata.params or {}

  if params == vim.NIL then
    return {}
  end

  return params
end

local function normalize_path(path)
  if not path or path == "" then
    return ""
  end

  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local function set_cursor(win, line, column)
  column = math.max((column or 1) - 1, 0)
  pcall(vim.api.nvim_win_set_cursor, win, { line, column })
  pcall(vim.api.nvim_set_current_win, win)
  pcall(vim.api.nvim_win_call, win, function()
    vim.cmd("normal! zv")
  end)
end

local function find_window_with_buffer(bufnr)
  local current_tab = vim.api.nvim_get_current_tabpage()
  local tabpages = { current_tab }

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if tabpage ~= current_tab then
      tabpages[#tabpages + 1] = tabpage
    end
  end

  for _, tabpage in ipairs(tabpages) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_get_buf(win) == bufnr then
        return tabpage, win
      end
    end
  end
end

local function switch_to_source(bufnr, line, column)
  local tabpage, win = find_window_with_buffer(bufnr)
  if win then
    pcall(vim.api.nvim_set_current_tabpage, tabpage)
    set_cursor(win, line, column)
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    -- Do not replace leetcode.nvim's winfixbuf question window. A split opened
    -- with a filename creates a fresh, non-fixed window for non-LeetCode sources
    -- that are not already visible.
    vim.cmd("rightbelow split " .. vim.fn.fnameescape(name))
  else
    vim.cmd("rightbelow new")
    vim.api.nvim_win_set_buf(0, bufnr)
  end

  set_cursor(vim.api.nvim_get_current_win(), line, column)
end

local function leetcode_switchbuf(harness_path)
  local normalized_harness = normalize_path(harness_path)

  return function(bufnr, line, column)
    local target = normalize_path(vim.api.nvim_buf_get_name(bufnr))

    if target == normalized_harness then
      -- Stepping out of the user's Solution method lands in this generated
      -- harness. Keep that implementation detail hidden: continue naturally so
      -- the debuggee either exits or reaches the next user breakpoint/testcase.
      vim.schedule(function()
        local ok, dap = pcall(require, "dap")
        local session = ok and dap.session()
        if session and session.config and normalize_path(session.config.program) == normalized_harness then
          dap.continue()
        end
      end)
      return
    end

    switch_to_source(bufnr, line, column)
  end
end

local function has_session_with_program(dap, program)
  for _, session in pairs(dap.sessions()) do
    if session.config and normalize_path(session.config.program) == program then
      return true
    end
  end

  return false
end

local function remove_stack_entry(stack, entry)
  for index = #stack, 1, -1 do
    if stack[index] == entry then
      table.remove(stack, index)
      return
    end
  end
end

local function restore_debugpy_switchbuf(dap, handler)
  local stack = switchbuf_state.debugpy_stack
  local top = stack[#stack]

  if dap.defaults.debugpy.switchbuf == handler then
    dap.defaults.debugpy.switchbuf = top and top.handler or switchbuf_state.debugpy_base
  end

  if #stack == 0 then
    switchbuf_state.debugpy_base = nil
  end
end

local function with_leetcode_switchbuf(dap, harness_path)
  local handler = leetcode_switchbuf(harness_path)
  local normalized_harness = normalize_path(harness_path)
  local listener_id = "leetcode_debug_switchbuf_" .. vim.fn.sha256(harness_path)
  local stack = switchbuf_state.debugpy_stack
  local entry = {
    handler = handler,
    harness = normalized_harness,
  }
  local restored = false

  if #stack == 0 then
    switchbuf_state.debugpy_base = dap.defaults.debugpy.switchbuf
  end

  -- Unique per-run harness paths keep simultaneous/near-simultaneous teardown
  -- from restoring the wrong handler. The stack preserves any user/project
  -- debugpy switchbuf value that existed before LeetDebug touched it.
  stack[#stack + 1] = entry
  dap.defaults.debugpy.switchbuf = handler

  local function restore(session)
    if restored then
      return
    end
    if not (session and session.config and normalize_path(session.config.program) == normalized_harness) then
      return
    end

    restored = true
    remove_stack_entry(stack, entry)
    restore_debugpy_switchbuf(dap, handler)
    dap.listeners.after.event_terminated[listener_id] = nil
    dap.listeners.on_session[listener_id] = nil
  end

  dap.listeners.after.event_terminated[listener_id] = restore
  dap.listeners.on_session[listener_id] = function(old_session)
    if old_session
        and old_session.config
        and normalize_path(old_session.config.program) == normalized_harness
        and not has_session_with_program(dap, normalized_harness) then
      restore(old_session)
    end
  end
end

local function is_leetcode_debug_session(session)
  local config = session and session.config
  local name = config and config.name
  local program = config and config.program

  return type(name) == "string"
      and vim.startswith(name, "LeetCode: ")
      and type(program) == "string"
      and vim.startswith(normalize_path(program), normalize_path(debug_dir) .. "/")
end

local function terminate_session_quietly(session, on_done)
  on_done = on_done or function() end

  if not session or session.closed then
    on_done()
    return
  end

  local function terminate()
    if session.closed then
      on_done()
      return
    end

    local capabilities = session.capabilities or {}
    if capabilities.supportsTerminateRequest then
      capabilities.supportsTerminateRequest = false
      local timeout_sec = (session.adapter.options or {}).disconnect_timeout_sec or 3
      session:request_with_timeout("terminate", vim.empty_dict(), timeout_sec * 1000, function()
        if not session.closed then
          session:close()
        end
        on_done()
      end)
    else
      session:disconnect({ terminateDebuggee = true }, function()
        on_done()
      end)
    end
  end

  -- Let nvim-dap/dap-ui finish stack/scopes requests from a just-received stop
  -- event before replacing the short-lived LeetDebug session. Terminating in
  -- the same tick can produce harmless but noisy "disconnected unexpectedly"
  -- stack-trace notifications from the old session.
  vim.defer_fn(terminate, 100)
end

local function replace_active_leetcode_sessions(dap, on_done)
  -- dap.run(config) restarts the active session when the active config has the
  -- same name. LeetDebug names are intentionally stable per problem, so reruns
  -- must replace the old LeetDebug session first or nvim-dap reports "Session
  -- terminated" and may not reopen dap-ui for the new run.
  local sessions = {}
  for _, session in pairs(dap.sessions()) do
    if is_leetcode_debug_session(session) then
      sessions[#sessions + 1] = session
    end
  end

  if #sessions == 0 then
    on_done()
    return
  end

  local remaining = #sessions
  local completed = {}
  local function mark_done(session)
    if completed[session] then
      return
    end

    completed[session] = true
    remaining = remaining - 1
    if remaining == 0 then
      vim.schedule(on_done)
    end
  end

  for _, session in ipairs(sessions) do
    terminate_session_quietly(session, function()
      mark_done(session)
    end)
  end
end

local function harness_source()
  return [=[#!/usr/bin/env python3
"""Generated by Stanley's Neovim config for local leetcode.nvim debugging."""

import ast
import json
import linecache
import pathlib
import sys
from collections import deque


class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

    def __repr__(self):
        return repr(listnode_to_list(self))


class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

    def __repr__(self):
        return repr(treenode_to_list(self))


class Node:
    def __init__(self, val=0, neighbors=None, next=None, random=None, children=None):
        self.val = val
        self.neighbors = neighbors if neighbors is not None else []
        self.next = next
        self.random = random
        self.children = children if children is not None else []

    def __repr__(self):
        return f"Node({self.val!r})"


def list_to_listnode(values):
    if values is None:
        return None

    dummy = ListNode()
    tail = dummy
    for value in values:
        tail.next = ListNode(value)
        tail = tail.next
    return dummy.next


def listnode_to_list(node):
    values = []
    seen = set()

    while node is not None:
        if id(node) in seen:
            values.append("<cycle>")
            break
        seen.add(id(node))
        values.append(node.val)
        node = node.next

    return values


def list_to_treenode(values):
    if values is None:
        return None
    if not values:
        return None

    nodes = [None if value is None else TreeNode(value) for value in values]
    children = nodes[::-1]
    root = children.pop()

    for node in nodes:
        if node is None:
            continue
        if children:
            node.left = children.pop()
        if children:
            node.right = children.pop()

    return root


def treenode_to_list(root):
    if root is None:
        return []

    values = []
    queue = deque([root])
    while queue:
        node = queue.popleft()
        if node is None:
            values.append(None)
            continue

        values.append(node.val)
        queue.append(node.left)
        queue.append(node.right)

    while values and values[-1] is None:
        values.pop()

    return values


def to_builtin(value):
    if isinstance(value, ListNode):
        return listnode_to_list(value)
    if isinstance(value, TreeNode):
        return treenode_to_list(value)
    if isinstance(value, list):
        return [to_builtin(item) for item in value]
    if isinstance(value, tuple):
        return tuple(to_builtin(item) for item in value)
    if isinstance(value, dict):
        return {key: to_builtin(item) for key, item in value.items()}
    return value


def parse_value(raw):
    raw = raw.strip()

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    try:
        return ast.literal_eval(raw)
    except (SyntaxError, ValueError):
        return raw


def adapt_arg(value, type_name):
    type_name = (type_name or "").lower()

    if "listnode" in type_name:
        return list_to_listnode(value)
    if "treenode" in type_name:
        return list_to_treenode(value)

    return value


def extract_leet_sections(source):
    lines = source.splitlines()
    keep = [False] * len(lines)
    active = False
    saw_section = False

    for index, line in enumerate(lines):
        text = line.strip()
        starts_section = "@leet imports start" in text or "@leet start" in text
        ends_section = "@leet imports end" in text or "@leet end" in text

        if starts_section:
            active = True
            saw_section = True
            keep[index] = True
            continue

        if active:
            keep[index] = True

        if ends_section:
            active = False

    if not saw_section:
        return source if source.endswith("\n") else source + "\n"

    return "\n".join(line if keep[index] else "" for index, line in enumerate(lines)) + "\n"


def cases_from_input(data_input, param_types):
    lines = [line for line in data_input.splitlines() if line != ""]
    param_count = len(param_types)

    if param_count == 0:
        raise RuntimeError("No LeetCode parameter metadata found; design/database problems are not supported yet.")

    if len(lines) % param_count != 0:
        raise RuntimeError(
            f"Expected custom testcase line count to be a multiple of {param_count}, got {len(lines)}."
        )

    cases = []
    for offset in range(0, len(lines), param_count):
        raw_args = lines[offset : offset + param_count]
        parsed = [parse_value(raw) for raw in raw_args]
        cases.append([adapt_arg(value, param_types[index]) for index, value in enumerate(parsed)])

    return cases


def load_solution(solution_file, solution_source):
    source = extract_leet_sections(solution_source)
    linecache.cache[str(solution_file)] = (len(source), None, source.splitlines(True), str(solution_file))

    namespace = {
        "__name__": "__leetcode_debug_solution__",
        "ListNode": ListNode,
        "TreeNode": TreeNode,
        "Node": Node,
    }
    exec(compile(source, str(solution_file), "exec"), namespace)
    return namespace


def main():
    if len(sys.argv) != 2:
        raise RuntimeError("Usage: leetcode_debug.py REQUEST_JSON")

    request_path = pathlib.Path(sys.argv[1])
    request = json.loads(request_path.read_text())

    solution_file = pathlib.Path(request["solution_file"])
    method_name = request["method_name"]
    param_types = request["param_types"]
    param_names = request["param_names"]
    data_input = request["data_input"]

    namespace = load_solution(solution_file, request["solution_source"])
    solution_class = namespace.get("Solution")
    if solution_class is None:
        raise RuntimeError("Expected `class Solution` in the LeetCode code section; design problems are not supported yet.")

    cases = cases_from_input(data_input, param_types)

    print(f"Debugging {solution_file}")
    print(f"Method: Solution.{method_name}({', '.join(param_names)})")
    print(f"Cases: {len(cases)}")

    for index, args in enumerate(cases, start=1):
        print(f"\n== Case {index} ==")
        print("args =", repr(to_builtin(args)))
        solution = solution_class()
        method = getattr(solution, method_name)
        result = method(*args)
        print("result =", repr(to_builtin(result)))


if __name__ == "__main__":
    main()
]=]
end

function M.debug_current()
  local ok_utils, leetcode_utils = pcall(require, "leetcode.utils")
  if not ok_utils then
    notify("leetcode.nvim is not loaded yet", vim.log.levels.WARN)
    return
  end

  local question = leetcode_utils.curr_question()
  if not question then
    notify("Open a LeetCode question before starting the debugger", vim.log.levels.WARN)
    return
  end

  if question.lang ~= "python3" and question.lang ~= "python" then
    notify("Local LeetCode debugging is currently Python-only", vim.log.levels.WARN)
    return
  end

  local path = question_file(question)
  if not path or path == "" then
    notify("Could not resolve the current LeetCode question file", vim.log.levels.ERROR)
    return
  end

  local metadata = value_or(question.q and question.q.meta_data, {})
  local method_name = value_or(metadata.name)
  if not method_name then
    notify("Could not resolve the current LeetCode method name", vim.log.levels.ERROR)
    return
  end

  local params = metadata_params(question)
  local param_names = {}
  local param_types = {}
  for _, param in ipairs(params) do
    param_names[#param_names + 1] = tostring(value_or(param.name, "arg" .. (#param_names + 1)))
    param_types[#param_types + 1] = tostring(value_or(param.type, ""))
  end

  local input = testcase_content(question)
  if input == "" then
    notify("No custom testcase input found in the LeetCode console", vim.log.levels.WARN)
    return
  end

  local slug = sanitize_filename(value_or(question.q and question.q.title_slug, vim.fn.fnamemodify(path, ":t:r")))
  local run_id = ("%x"):format(vim.uv.hrtime())
  local harness_path = vim.fs.joinpath(debug_dir, slug .. "_" .. run_id .. "_debug.py")
  local request_path = vim.fs.joinpath(debug_dir, slug .. "_" .. run_id .. "_debug.json")

  local request = {
    version = 1,
    solution_file = path,
    solution_source = question_source(question, path),
    method_name = method_name,
    param_names = param_names,
    param_types = param_types,
    data_input = input,
  }

  write_text(harness_path, harness_source())
  write_text(request_path, vim.json.encode(request))

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    notify("nvim-dap is not available: " .. tostring(dap), vim.log.levels.ERROR)
    return
  end

  local config = {
    type = "debugpy",
    request = "launch",
    name = "LeetCode: " .. slug,
    program = harness_path,
    args = { request_path },
    cwd = vim.fs.dirname(path),
    console = "integratedTerminal",
    justMyCode = true,
    pythonPath = project_python,
    env = {
      PYTHONUNBUFFERED = "1",
    },
  }

  replace_active_leetcode_sessions(dap, function()
    with_leetcode_switchbuf(dap, harness_path)
    dap.run(config, { new = true })
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("LeetDebug", function()
    M.debug_current()
  end, {
    desc = "Debug the current leetcode.nvim question with the console testcases",
  })
end

return M
