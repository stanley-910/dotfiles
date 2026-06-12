-- LuaSnip snippets for the `lua` filetype.
--
-- DORMANT until LuaSnip is booted: this file is only read by the
-- `luasnip.loaders.from_lua` loader, which is commented out in
-- lua/plugins/luasnip.lua. Nothing here runs today.
--
-- from_lua convention: a file named `<filetype>.lua` returns a list of
-- snippets that apply to that filetype.

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local t = ls.text_node
local c = ls.choice_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt

-- DYNAMIC NODE callback: reads the params (watched node) and emits one
-- `---@param <name> <type>` line per comma-separated argument, live.
local function param_docs(args)
  local params = args[1][1] or "" -- args[1] = lines of the watched node; [1] = first line
  local nodes, idx = {}, 1
  for name in params:gmatch("[^,%s]+") do
    table.insert(nodes, t({ "", "---@param " .. name .. " " }))
    table.insert(nodes, i(idx, "any")) -- a fillable type per param
    idx = idx + 1
  end
  if #nodes == 0 then
    nodes = { t("") }
  end
  return sn(nil, nodes) -- dynamic nodes must return a snippet_node
end

local fn = s(
  "fn",
  fmt(
    [[
      --- {desc}
      {param_docs}
      ---@return {ret}
      {scope}function {name}({params})
        {body}
      end
    ]],
    {
      desc = i(1, "description"),
      scope = c(2, { t("local "), t("") }), -- CHOICE NODE: local vs global
      name = i(3, "fn_name"),
      params = i(4, "a, b"),
      param_docs = d(5, param_docs, { 4 }), -- DYNAMIC NODE watching node 4
      ret = i(6, "any"),
      body = i(0, "-- ..."), -- i(0) = final cursor
    }
  )
)

return { fn }
