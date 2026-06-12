-- THE ZED FLOW (the screenshot use case):
--   1. Visually select the lines (V, then j to extend), or just put the cursor in
--      a paragraph.
--   2. `ga` + a motion/textobject → a cursor on each line:
--        `gaip`  cursor on every line of the paragraph
--        (in visual mode) `ga`  cursor on every selected line
--   3. Run any normal-mode edit — `ci"NEW<esc>`, `A,<esc>`, `>`, etc. — it fires
--      at every cursor. `<esc>` collapses back to one cursor.
--
-- Other entry points:
--   <up>/<down>            add a cursor on the line above/below (n, x)
--   <leader><up>/<down>    skip a line, then add a cursor (leave gaps)
--   <leader>n / <leader>N  add a cursor at the next/prev match of the word or
--                          visual selection — the VS Code Ctrl-d "select next" flow
--   <leader>s / <leader>S  skip the next/prev match instead of adding
--   <c-q>                  toggle the cursor under you on/off
--   (visual) I / A         insert / append at the start/end of every selected line
--   (visual) S / M         split / match selection into cursors by regex prompt
--   Ctrl + left-click      add/remove a cursor with the mouse
--
-- WHILE MULTIPLE CURSORS ARE ACTIVE (these maps only exist then — see the keymap
-- layer at the bottom; they overlay your normal maps and vanish afterward):
--   <left>/<right>         make the prev/next cursor the "main" one
--   <esc>                  first press disables cursors, second clears them
--
-- Keymap notes / conflict audit (this config):
--   * <up>/<down>/<c-q>/<leader>{n,s,N,S} are unmapped elsewhere in
--     config/keymap.lua. Plain normal-mode arrow movement is sacrificed to the
--     add-cursor convention; j/k still move. Swap to <C-Up>/<C-Down> below if you
--     want your arrows back (those Ctrl-arrow slots are free — Treewalker's are
--     commented out in treewalker.lua).
--   * `ga` only shadows Vim's rarely-used "print char code" builtin; it's the
--     plugin's own recommended binding for addCursorOperator.
--   * <leader>x is intentionally NOT used (whichkey.lua reserves it as the Trouble
--     diagnostics group). Cursor deletion lives on the layer key <leader>d below,
--     active only during a multicursor session.
--
-- Uses `config`+`setup()` rather than `opts` because the keymap-layer API
-- (addKeymapLayer) must be called imperatively. To remove: delete this file.
--
-- See :h multicursor and https://github.com/jake-stewart/multicursor.nvim
return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0", -- pin to the stable 1.0 branch (the README's recommended ref)
  event = "VeryLazy",
  config = function()
    local mc = require("multicursor-nvim")
    mc.setup()

    local set = vim.keymap.set

    -- The Zed flow: cursor on each line of a motion/visual selection.
    set({ "n", "x" }, "ga", mc.addCursorOperator, { desc = "MC: add cursor per line (e.g. gaip)" })

    -- Add / skip a cursor on the line above or below.
    set({ "n", "x" }, "<up>", function() mc.lineAddCursor(-1) end, { desc = "MC: add cursor up" })
    set({ "n", "x" }, "<down>", function() mc.lineAddCursor(1) end, { desc = "MC: add cursor down" })

    -- Add / skip a cursor by matching the word or visual selection (Ctrl-d style).
    set({ "n", "x" }, "<leader>n", function() mc.matchAddCursor(1) end, { desc = "MC: add cursor at next match" })
    set({ "n", "x" }, "<leader>N", function() mc.matchAddCursor(-1) end, { desc = "MC: add cursor at prev match" })

    -- Insert / append for each line of a visual selection (like block I/A).
    set("x", "I", mc.insertVisual, { desc = "MC: insert at start of each line" })
    set("x", "A", mc.appendVisual, { desc = "MC: append at end of each line" })

    -- Split / match a visual selection into cursors via a regex prompt.
    -- TODO make this into groups
    set("x", "<leader>cs", mc.splitCursors, { desc = "MC: split selection by regex" })
    set("x", "<leader>cm", mc.matchCursors, { desc = "MC: match cursors in selection by regex" })

    -- Toggle the cursor under you on/off.
    set({ "n", "x" }, "<c-q>", mc.toggleCursor, { desc = "MC: toggle cursor" })

    -- Mouse: Ctrl + click to add/remove cursors.
    set("n", "<c-leftmouse>", mc.handleMouse, { desc = "MC: add cursor (mouse)" })
    set("n", "<c-leftdrag>", mc.handleMouseDrag, { desc = "MC: drag cursors (mouse)" })
    set("n", "<c-leftrelease>", mc.handleMouseRelease, { desc = "MC: release cursors (mouse)" })

    -- Layer: these maps exist ONLY while multiple cursors are active, so they can
    -- safely overlap your normal maps.
    mc.addKeymapLayer(function(layerSet)
      layerSet({ "n", "x" }, "<left>", mc.prevCursor, { desc = "MC: focus prev cursor" })
      layerSet({ "n", "x" }, "<right>", mc.nextCursor, { desc = "MC: focus next cursor" })
      layerSet({ "n", "x" }, "<leader>d", mc.deleteCursor, { desc = "MC: delete main cursor" })
      layerSet("n", "<esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        else
          mc.clearCursors()
        end
      end, { desc = "MC: disable / clear cursors" })
    end)

    -- Cursor appearance — link into the active colorscheme.
    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { reverse = true })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorMatchPreview", { link = "Search" })
    hl(0, "MultiCursorDisabledCursor", { reverse = true })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
  end,
}
