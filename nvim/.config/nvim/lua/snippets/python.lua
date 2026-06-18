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
local fmt = require("luasnip.extras.fmt").fmt

local function return_annotation(pos)
  return c(pos, {
    t(""),
    sn(nil, { t(" -> "), i(1, "None") }),
  })
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
        i(0, "pass"),
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
