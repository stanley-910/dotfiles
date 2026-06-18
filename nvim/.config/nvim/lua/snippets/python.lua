-- LuaSnip snippets for the `python` filetype.
--
-- Loaded by lua/plugins/luasnip.lua via `luasnip.loaders.from_lua`.
-- The file name matters: python.lua applies when `:set filetype?` is `python`.

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local t = ls.text_node
local c = ls.choice_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt

local function return_annotation(pos)
  return c(pos, {
    t(""),
    sn(nil, { t(" -> "), i(1, "None") }),
  })
end

local function init_arg_name(raw_arg)
  local name = vim.trim(raw_arg)
  if name == "" or name == "*" or name == "/" then
    return nil
  end

  -- Support common Python parameter shapes:
  --   arg, arg: str, arg = default, *args, **kwargs
  -- All should assign the runtime variable name, not the annotation/default.
  name = name:gsub("^%*+", "")
  name = name:match("^([%a_][%w_]*)")

  if name == "self" or name == "cls" then
    return nil
  end

  return name
end

local function init_assignments(indent)
  return function(args)
    local params = args[1][1] or ""
    local lines = {}

    for raw_arg in params:gmatch("[^,]+") do
      local name = init_arg_name(raw_arg)
      if name ~= nil then
        table.insert(lines, ("self.%s = %s"):format(name, name))
      end
    end

    if #lines == 0 then
      return sn(nil, { i(1, "pass") })
    end

    -- LuaSnip only inherits the template indentation for the first generated
    -- line, so prefix subsequent dynamic lines explicitly.
    for index = 2, #lines do
      lines[index] = indent .. lines[index]
    end

    return sn(nil, { t(lines) })
  end
end

return {
  s(
    "defn",
    fmt(
      [[
def {}({}){}:
    {}
]],
      {
        i(1, "name"),
        i(2),
        return_annotation(3),
        i(0, "pass"),
      }
    )
  ),

  s(
    "adef",
    fmt(
      [[
async def {}({}){}:
    {}
]],
      {
        i(1, "name"),
        i(2),
        return_annotation(3),
        i(0, "pass"),
      }
    )
  ),

  s(
    "init",
    fmt(
      [[
def __init__(self, {}):
    {}
]],
      {
        i(1),
        d(2, init_assignments("    "), { 1 }),
      }
    )
  ),

  s(
    "cls",
    fmt(
      [[
class {}:
    def __init__(self, {}):
        {}
]],
      {
        i(1, "ClassName"),
        i(2),
        d(3, init_assignments("        "), { 2 }),
      }
    )
  ),

  s(
    "main",
    fmt(
      [[
def main(){}:
    {}

if __name__ == "__main__":
    main()
]],
      {
        return_annotation(1),
        i(0, "pass"),
      }
    )
  ),

  s(
    "test",
    fmt(
      [[
def test_{}():
    {}
]],
      {
        i(1, "behavior"),
        i(0, "assert False"),
      }
    )
  ),
}
