-- Normal-mode <C-a>/<C-x> only flip a value at or to the RIGHT of the cursor
-- (same as native Vim). Parking the cursor at end-of-line usually lands it on a
-- trailing "," / ";" / ")" / "}", leaving the actual value just to the LEFT, so
-- nothing flips. This wrapper runs dial as usual and ONLY when nothing changed
-- (vim.b.changedtick is the "a flip happened" signal) steps the cursor left over
-- the trailing run of whitespace/punctuation onto the value's last char and
-- retries once. If there was still nothing to flip, the original cursor is
-- restored. Because it acts solely on a no-op, cursor-on-value behavior is
-- untouched — this only RESCUES the previously-dead end-of-line case. (count is
-- captured up front and passed explicitly so g<C-a>'s count survives the second
-- call.) Visual-mode maps below keep dial's own range and skip this.
local function dial(direction, mode)
  return function()
    local manipulate = require("dial.map").manipulate
    local count = vim.v.count1
    local tick = vim.b.changedtick
    manipulate(direction, mode, nil, count)
    if vim.b.changedtick ~= tick then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(0) -- { row, 0-based col }
    local line = vim.api.nvim_get_current_line()
    local col = pos[2]
    -- char under cursor is line:sub(col + 1, col + 1); walk left over the
    -- trailing whitespace/punctuation to the end of the preceding value.
    while col > 0 and line:sub(col + 1, col + 1):match("[%s%p]") do
      col = col - 1
    end
    if col ~= pos[2] then
      vim.api.nvim_win_set_cursor(0, { pos[1], col })
      manipulate(direction, mode, nil, count)
    end
    if vim.b.changedtick == tick then
      vim.api.nvim_win_set_cursor(0, pos)
    end
  end
end

return {
  "monaqa/dial.nvim",
  keys = {
    {
      "<C-a>",
      dial("increment", "normal"),
      mode = "n",
      desc = "Increment smart value",
    },
    {
      "<C-x>",
      dial("decrement", "normal"),
      mode = "n",
      desc = "Decrement smart value",
    },
    {
      "g<C-a>",
      dial("increment", "gnormal"),
      mode = "n",
      desc = "Increment smart value with count",
    },
    {
      "g<C-x>",
      dial("decrement", "gnormal"),
      mode = "n",
      desc = "Decrement smart value with count",
    },
    {
      "<C-a>",
      function()
        require("dial.map").manipulate("increment", "visual", "visual")
      end,
      mode = "x",
      desc = "Increment selected smart values",
    },
    {
      "<C-x>",
      function()
        require("dial.map").manipulate("decrement", "visual", "visual")
      end,
      mode = "x",
      desc = "Decrement selected smart values",
    },
    {
      "g<C-a>",
      function()
        require("dial.map").manipulate("increment", "gvisual", "visual")
      end,
      mode = "x",
      desc = "Increment selected smart values with count",
    },
    {
      "g<C-x>",
      function()
        require("dial.map").manipulate("decrement", "gvisual", "visual")
      end,
      mode = "x",
      desc = "Decrement selected smart values with count",
    },
  },
  config = function()
    local augend = require("dial.augend")
    local config = require("dial.config")

    local function constant(elements, word, cyclic)
      return augend.constant.new({
        elements = elements,
        word = word ~= false,
        cyclic = cyclic ~= false,
      })
    end

    local function concat(...)
      local result = {}
      for _, list in ipairs({ ... }) do
        vim.list_extend(result, list)
      end
      return result
    end

    local default_augends = {
      -- Specific structured values first so dates/versions/colors win over raw numbers.
      augend.hexcolor.new({ case = "prefer_lower" }),
      augend.semver.alias.semver,
      augend.date.alias["%Y-%m-%d"],
      augend.date.alias["%Y/%m/%d"],
      augend.date.alias["%m/%d/%Y"],
      augend.date.alias["%m/%d/%y"],
      augend.date.alias["%m/%d"],
      augend.date.alias["%-m/%-d"],
      augend.date.alias["%H:%M:%S"],
      augend.date.alias["%H:%M"],

      -- Numbers: signed decimal plus common prefixed bases.
      augend.integer.alias.decimal_int,
      augend.integer.alias.hex,
      augend.integer.alias.octal,
      augend.integer.alias.binary,

      -- Common booleans and toggles.
      augend.constant.alias.bool,
      augend.constant.alias.Bool,
      constant({ "TRUE", "FALSE" }),
      constant({ "yes", "no" }),
      constant({ "on", "off" }),
      constant({ "enable", "disable" }),
      constant({ "enabled", "disabled" }),
      constant({ "and", "or" }),
      constant({ "&&", "||" }, false),

      -- Human date words.
      augend.constant.alias.en_weekday,
      augend.constant.alias.en_weekday_full,
      constant({ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }),
      constant({
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      }),
    }

    local visual_augends = concat(default_augends, {
      -- Only visual mode gets alphabet cycling; normal-mode <C-a> on a stray
      -- "a" in prose/code is too surprising.
      augend.constant.alias.alpha,
      augend.constant.alias.Alpha,
    })

    local markdown_augends = concat(default_augends, {
      constant({ "#", "##", "###", "####", "#####", "######" }, false, false),
      constant({ "[ ]", "[x]" }, false),
    })

    local javascript_augends = concat(default_augends, {
      constant({ "let", "const" }),
    })

    config.augends:register_group({
      default = default_augends,
      visual = visual_augends,
    })

    config.augends:on_filetype({
      markdown = markdown_augends,
      javascript = javascript_augends,
      javascriptreact = javascript_augends,
      typescript = javascript_augends,
      typescriptreact = javascript_augends,
      vue = javascript_augends,
      svelte = javascript_augends,
    })
  end,
}
