# Known Issues

## Diagnostic jump float does not open for offscreen diagnostics

Status: unresolved; leave current `lsp.lua` behavior as-is unless there is time for a cleaner live-UI diagnosis.

### Symptom

`[d` and `]d` jump to the previous/next diagnostic, but the diagnostic detail float only appears when the target diagnostic is already in the current viewport. If the target diagnostic is offscreen, Neovim moves the cursor there, but the diagnostic hover/float does not remain visible.

### Affected area

- `nvim/.config/nvim/lua/config/lsp.lua`
- Mappings installed on `LspAttach`:
  - `]d` → next diagnostic
  - `[d` → previous diagnostic
- Helper involved: `jump_diagnostic(count)` using `vim.diagnostic.jump({ on_jump = ... })`

### Repro steps

1. Open a file with LSP diagnostics where at least one diagnostic is outside the current viewport.
2. Place the cursor far enough away that the target diagnostic is not visible.
3. Press `]d` or `[d` to jump to that diagnostic.
4. Observe:
   - Cursor moves to the diagnostic line.
   - Expected: diagnostic float opens and shows the message.
   - Actual: float does not appear / does not remain visible.
5. Scroll so the diagnostic is already visible, then press `[d` / `]d` again.
6. Observe that the float works when the target diagnostic starts in the viewport.

### Failed attempts

Do not blindly reapply these; they did not fix the real UI behavior cleanly.

1. Temporarily disabled `b:snacks_scroll` during diagnostic jumps.
   - Rationale: suspected smooth-scroll animation emitted cursor/view events that closed the float.
   - Result: did not fix the user-visible issue.
2. Removed `CursorMoved` from the jump float's immediate `close_events` and added a delayed one-shot close autocmd.
   - Rationale: let the float survive jump-triggered `CursorMoved`, then close on the next real move.
   - Result: passed a headless scratch repro but failed in the real UI.

### Useful docs for future diagnosis

- `:help vim.diagnostic.jump()`
- `:help vim.diagnostic.open_float()`
- `:help diagnostic-on-jump-example`
- `:help nvim_open_win()`
- `:help CursorMoved`

### Notes for next attempt

A useful next diagnosis should happen in the real UI, not only headless, and should log the exact order of:

- `vim.diagnostic.jump()` callback execution
- `CursorMoved` / `WinScrolled` events
- diagnostic float creation
- diagnostic float close events
- any plugin scroll/animation hooks

If no clean fix appears, prefer leaving `[d` / `]d` as plain navigation and using `gl` / `K` to inspect diagnostics after landing.
