-- mini.ai — extend and create `a`/`i` textobjects.
--
-- Enhances builtin textobjects (a(, a), a", ...) and adds new ones, all under
-- the familiar `a`/`i` prefixes in Operator-pending and Visual modes. Highlights:
--   af / if   Treesitter function      (function/method/lambda node)
--   ac / ic   Treesitter function call (call expression / arguments)
--   aC / iC   Treesitter class         (class/interface/type-ish region)
--   ap / ip   paragraph                (native textobject fallback)
--   ai / ii   Treesitter conditional   (if/switch/ternary-ish region)
--   al / il   Treesitter loop          (for/while/etc.)
--   aB / iB   Treesitter block         ({ ... } / block node)
--   ao / io   Treesitter control block (nearest conditional, loop, or block)
--   ak / ik   Treesitter comment block (continuous standalone comment lines)
--   at / it   tag                      (<div>...</div>)
--   aq / iq   any quote   ab/ib any bracket   a?/i? prompt for custom delimiters
--   a<Space>  whitespace               plus a<punct>/a<digit> for non-letters
-- Full default list: :h MiniAi-builtin-textobjects
--
-- Defaults are kept as-is (see :h MiniAi.config) — sensible out of the box:
--   n_lines = 50, search_method = 'cover_or_next', goto edges on g[ / g].
--
-- No keymap conflicts: nothing in config/keymap.lua maps `a`/`i` in
-- operator/visual mode, nor g[ / g]. config/keymap.lua line ~374 explicitly
-- reserved this slot ("Rich textobjects: nvim-mini/mini.ai").
--
-- NOTE: mini.ai's default an/in next-textobject mappings conflict with
-- Neovim 0.12's builtin incremental-selection maps (:h v_an / :h v_in), so
-- keep an/in for native Treesitter/LSP node selection and disable mini.ai's
-- next/last variants below. See :h MiniAi.config.
--
-- Interaction with substitute.nvim: the `x` operator (gbprod/substitute) drives
-- `g@`/operatorfunc, so these textobjects apply automatically — `xif` substitutes
-- inside a function body, `xic` substitutes call arguments, etc. No extra mapping.
--
-- Treesitter-backed objects depend on reachable `textobjects.scm` queries. The
-- companion nvim-treesitter-textobjects plugin supplies those captures; verify
-- with: :lua =vim.treesitter.query.get_files(vim.bo.filetype, 'textobjects')
--
-- To remove: delete this file; the reserved-slot comment in keymap.lua still
-- documents the intent.
--
-- See: https://github.com/nvim-mini/mini.ai
return {
  "nvim-mini/mini.ai",
  version = "*", -- track tagged releases for stability
  event = "VeryLazy",
  opts = function()
    local ai = require("mini.ai")
    local ts = ai.gen_spec.treesitter
    local control = {
      "@conditional.outer",
      "@loop.outer",
      "@block.outer",
    }
    local control_inner = {
      "@conditional.inner",
      "@loop.inner",
      "@block.inner",
    }

    local function single_line_comment_inner(line, line_nr, start_col, end_col)
      local comment_text = line:sub(start_col + 1, end_col)
      local opener_patterns = {
        "^%s*<!%-%-%s?",
        "^%s*/%*+%s?",
        "^%s*%-%-%[%[?%s?",
        "^%s*%-%-%-%s?",
        "^%s*%-%-%s?",
        "^%s*//+%s?",
        "^%s*#+%s?",
        "^%s*;%s?",
        "^%s*\"%s?",
        "^%s*%%+%s?",
      }
      local closer_patterns = {
        "%s*%*/%s*$",
        "%s*%-%->%s*$",
        "%s*%]%]%s*$",
      }

      local leading = ""
      for _, pattern in ipairs(opener_patterns) do
        leading = comment_text:match(pattern) or ""
        if leading ~= "" then
          break
        end
      end

      local trailing = ""
      for _, pattern in ipairs(closer_patterns) do
        trailing = comment_text:match(pattern) or ""
        if trailing ~= "" then
          break
        end
      end

      local from_col = start_col + #leading + 1
      local to_col = end_col - #trailing
      if from_col > to_col then
        return nil
      end

      return {
        from = { line = line_nr, col = from_col },
        to = { line = line_nr, col = to_col },
        vis_mode = "v",
      }
    end

    local function comment_block(ai_type)
      local bufnr = vim.api.nvim_get_current_buf()
      local ok, parser = pcall(vim.treesitter.get_parser, bufnr, nil, { error = false })
      if not ok or not parser then
        return {}
      end

      parser:parse()

      local query = vim.treesitter.query.get(vim.bo[bufnr].filetype, "textobjects")
      if not query then
        return {}
      end

      local comment_capture_ids = {}
      for id, capture in ipairs(query.captures) do
        if capture == "comment.outer" then
          comment_capture_ids[id] = true
        end
      end
      if vim.tbl_isempty(comment_capture_ids) then
        return {}
      end

      local comment_lines = {}
      local inline_comments = {}
      for _, tree in ipairs(parser:trees()) do
        for capture_id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, -1) do
          if comment_capture_ids[capture_id] then
            local range = vim.treesitter.get_range(node, bufnr, metadata)
            local start_row, start_col, end_row, end_col = range[1], range[2], range[4], range[5]
            local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
            local prefix = line:sub(1, start_col)
            local region_end_row = end_row
            local region_end_col = end_col
            if end_col == 0 then
              region_end_row = end_row - 1
              region_end_col = vim.fn.col({ region_end_row + 1, "$" })
            end

            local is_single_line = start_row == region_end_row
            local inner_region = is_single_line and single_line_comment_inner(line, start_row + 1, start_col, region_end_col)
            if ai_type == "i" and inner_region then
              inline_comments[#inline_comments + 1] = inner_region
            elseif prefix:match("^%s*$") then
              for row = start_row, region_end_row do
                comment_lines[row + 1] = true
              end
            else
              -- Inline trailing comments are their own charwise object, so
              -- `dak` deletes only the comment and not the code before it.
              inline_comments[#inline_comments + 1] = {
                from = { line = start_row + 1, col = start_col + 1 },
                to = { line = region_end_row + 1, col = region_end_col },
                vis_mode = "v",
              }
            end
          end
        end
      end

      local blocks = {}
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local line = 1
      while line <= line_count do
        if comment_lines[line] then
          local start_line = line
          while line <= line_count and comment_lines[line] do
            line = line + 1
          end
          local end_line = line - 1
          blocks[#blocks + 1] = {
            from = { line = start_line, col = 1 },
            to = { line = end_line, col = vim.fn.col({ end_line, "$" }) },
            vis_mode = "V",
          }
        else
          line = line + 1
        end
      end

      vim.list_extend(blocks, inline_comments)
      table.sort(blocks, function(a, b)
        if a.from.line == b.from.line then
          return a.from.col < b.from.col
        end
        return a.from.line < b.from.line
      end)

      return blocks
    end

    return {
      custom_textobjects = {
        -- Override mini.ai's pattern-based function-call `f` with the canonical
        -- Treesitter function object. Calls move to `c` so `vaf` selects the
        -- whole function declaration/expression instead of just `name()`.
        f = ts({ a = "@function.outer", i = "@function.inner" }),
        c = ts({ a = "@call.outer", i = "@call.inner" }),
        C = ts({ a = "@class.outer", i = "@class.inner" }),
        i = ts({ a = "@conditional.outer", i = "@conditional.inner" }),
        l = ts({ a = "@loop.outer", i = "@loop.inner" }),
        B = ts({ a = "@block.outer", i = "@block.inner" }),
        o = ts({ a = control, i = control_inner }),

        -- `ak`/`ik` use `comment.outer` captures from textobjects.scm.
        -- Inner strips the delimiter for single-line comments.
        k = comment_block,
      },
      mappings = {
        -- Preserve Neovim 0.12 defaults: v_an / v_in select parent/child nodes.
        around_next = "",
        inside_next = "",
        around_last = "",
        inside_last = "",
      },
    }
  end,
}
