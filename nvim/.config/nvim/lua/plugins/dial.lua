return {
  "monaqa/dial.nvim",
  keys = {
    {
      "<C-a>",
      function()
        require("dial.map").manipulate("increment", "normal")
      end,
      mode = "n",
      desc = "Increment smart value",
    },
    {
      "<C-x>",
      function()
        require("dial.map").manipulate("decrement", "normal")
      end,
      mode = "n",
      desc = "Decrement smart value",
    },
    {
      "g<C-a>",
      function()
        require("dial.map").manipulate("increment", "gnormal")
      end,
      mode = "n",
      desc = "Increment smart value with count",
    },
    {
      "g<C-x>",
      function()
        require("dial.map").manipulate("decrement", "gnormal")
      end,
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
