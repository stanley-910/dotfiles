# Pi Runtime Scrollback Patch File Map

This note documents the local runtime changes made while experimenting with Pi's internal scrollback behavior and the `/btw` overlay. The changes live mostly outside this dotfiles repo, so another agent should start from this map instead of expecting everything under `~/dotfiles/pi/`.

## Scope

Goal of the local patch:

- Enable an internal, Claude/Copilot-style scrollback viewport for Pi interactive mode when `PI_INTERNAL_SCROLLBACK=1` is set.
- Keep Pi's normal editor/footer pinned while chat history scrolls.
- Add a copy/selection mode for the internal scrollback.
- Fix `/btw` so its bottom overlay can still scroll when the internal scrollback shim is active.

Reverted experiment:

- The Plan Mode / `ask_user_question` minimum-chat-viewport and overlay hit-test patch was reverted after confirming the observed behavior was default Plan Mode behavior, not a regression from this scrollback work. Copies of both the pre-experiment and with-experiment runtime files are preserved under `~/backups/pi-runtime-scrollback-20260605-111023/`.

## Important caveat

These are direct edits to installed runtime files:

- Homebrew global package files under `/opt/homebrew/lib/node_modules/...`
- Installed Pi package files under `~/.config/pi/agent/npm/node_modules/...`

They are **not** normal tracked dotfiles. A `pi update`, `npm update`, or package reinstall may overwrite them. Reproduce by reapplying the patches from the backup diffs listed below.

## File map

| Area | Live file | Why it matters |
|---|---|---|
| Pi interactive runtime | `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js` | Main internal scrollback implementation and overlay input guard. |
| Reverted Plan Mode experiment backup | `~/backups/pi-runtime-scrollback-20260605-111023/interactive-mode.js.with-plan-mode-experiment.bak` | Preserved copy of the unnecessary minimum-chat-viewport / overlay hit-test experiment. Not currently active. |
| Runtime copy used to revert Plan Mode experiment | `~/backups/pi-runtime-scrollback-20260605-111023/interactive-mode.js.pre-plan-mode-experiment.bak` | Preserved copy matching the restored live runtime after the revert. |
| Pi interactive runtime backup before Plan Mode viewport experiment | `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js.plan-mode-chat-viewport.20260605-110107.bak` | Original pre-experiment backup. The live file has been restored from this. |
| Pi interactive runtime backup before `/btw` fix | `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js.btw-overlay-scrollfix.20260605-100546.bak` | Diff this against the live file to see the `/btw` overlay-input guard. |
| Pi interactive runtime backup before internal scrollback patch | `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js.pi-internal-scrollback.20260604-155214.bak` | Diff this against the live file to see the larger internal scrollback patch. |
| Pi TUI terminal mouse mode | `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/dist/terminal.js` | Enables/disables SGR mouse reporting when `PI_INTERNAL_SCROLLBACK=1`; needed for wheel scrolling and mouse selection. |
| `/btw` overlay UI | `/Users/stanwang/.config/pi/agent/npm/node_modules/@juicesharp/rpiv-btw/btw-ui.ts` | Fixes `/btw` panel scroll direction and adds mouse-wheel handling. |
| `/btw` overlay UI backup before scroll fix | `/Users/stanwang/.config/pi/agent/npm/node_modules/@juicesharp/rpiv-btw/btw-ui.ts.scrollfix.20260605-100546.bak` | Diff this against the live file to see the `/btw` scrolling patch. |
| Dotfiles Pi package settings | `~/dotfiles/pi/.config/pi/agent/settings.json` | Tracks installed Pi package entries for reproducibility, but not runtime package contents. |
| Dotfiles Pi MCP config | `~/dotfiles/pi/.config/pi/agent/mcp.json` | Tracks MCP server config; relevant when testing overlay/popup interactions. |

## Hot spots inside `interactive-mode.js`

Current line numbers may drift after package updates, so search by symbol/comment.

| Symbol/search term | Approx. current line | Purpose |
|---|---:|---|
| `INTERNAL_SCROLLBACK_ENABLED` | `80` | Feature flag: internal scrollback is active only when `process.env.PI_INTERNAL_SCROLLBACK === "1"`. |
| `parseInternalScrollbackMouseEvent` | `83` | Parses SGR mouse events for wheel/drag/release. |
| `class InternalScrollbackLayout` | `150` | Composite layout that renders chat history as a scrollable area and keeps pending/status/widgets/editor/footer pinned. |
| `scrollToBottom()` | `194` | Resets scroll/copy/selection state when the user submits input. |
| `if (!INTERNAL_SCROLLBACK_ENABLED)` | `854` | Prevents the original header child from being added separately when internal scrollback owns the full layout. |
| `this.scrollbackLayout = new InternalScrollbackLayout` | `904` | Replaces the normal stacked TUI children with the scrollback layout. |
| `Let visible capturing overlays` | `917` | `/btw` fix: the internal scrollback input listener yields while a visible capturing overlay exists. |
| `setExtensionFooter` + `INTERNAL_SCROLLBACK_ENABLED` | `1934` | Footer replacement path when the footer is rendered inside `InternalScrollbackLayout`. |
| `showExtensionCustom` | `2278` | Overlay/custom UI creation path; useful for debugging popup focus/close issues. |
| `text === "/copy-mode" || text === "/scrollback"` | `2464` | Hidden commands that enter internal scrollback copy mode. |

## Hot spots inside `btw-ui.ts`

| Symbol/search term | Approx. current line | Purpose |
|---|---:|---|
| `SGR_MOUSE_EVENT` | `57` | Local parser for mouse-wheel events delivered to the `/btw` overlay. |
| `handleInput(data` | `106` | Routes wheel, escape, up/down, and `x` clear-history keys. |
| `this.scrollBy(1)` | `118` | Up arrow now reveals older clipped content. |
| `this.scrollBy(-1)` | `122` | Down arrow now moves back toward the newest/bottom content. |
| `this.scrollOffset = 0` in non-overflow render path | `155` | Prevents stale scroll offset after content shrinks below the max height. |
| `parseBtwMouseWheelDelta` | `225` | Converts SGR wheel-up/wheel-down to `/btw` overlay-local scroll deltas. |

## Reproduce / inspect the local patches

Use these commands to inspect exactly what changed from the saved backups:

```bash
# Larger internal scrollback patch against the original installed runtime backup
diff -u \
  /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js.pi-internal-scrollback.20260604-155214.bak \
  /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js

# Reverted Plan Mode / ask_user_question experiment, kept only for archaeology
# This should show the reverted minimum-chat-viewport / overlay hit-test patch.
diff -u \
  ~/backups/pi-runtime-scrollback-20260605-111023/interactive-mode.js.pre-plan-mode-experiment.bak \
  ~/backups/pi-runtime-scrollback-20260605-111023/interactive-mode.js.with-plan-mode-experiment.bak

# Follow-up that made overlays receive input before the scrollback shim
diff -u \
  /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js.btw-overlay-scrollfix.20260605-100546.bak \
  /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js

# /btw overlay scroll-direction + wheel handling fix
diff -u \
  /Users/stanwang/.config/pi/agent/npm/node_modules/@juicesharp/rpiv-btw/btw-ui.ts.scrollfix.20260605-100546.bak \
  /Users/stanwang/.config/pi/agent/npm/node_modules/@juicesharp/rpiv-btw/btw-ui.ts
```

## Run / verify

Start Pi with the feature flag:

```bash
PI_INTERNAL_SCROLLBACK=1 pi
```

Manual checks:

1. Create enough chat/tool output to exceed the terminal height.
2. Use mouse wheel to scroll the main chat history.
3. Run `/scrollback` or `/copy-mode` to enter copy mode.
4. Use `↑`/`↓`, `PgUp`/`PgDn`, `g`/`G`, `v`, `y`, and `Esc` in copy mode.
5. Open `/btw <question that produces a long answer>` and confirm:
   - the `/btw` panel receives `↑`/`↓`;
   - mouse wheel scrolls the `/btw` panel instead of the main chat;
   - `Esc` closes the panel cleanly.
6. Open popup-heavy UI such as MCP server/tool expansion and watch for duplicated lines on expand/close. If this regresses, inspect `showExtensionCustom`, overlay focus handling, and the internal scrollback input listener in `interactive-mode.js`.

Quick smoke commands used during the original patch:

```bash
node --check /opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/interactive-mode.js
PI_INTERNAL_SCROLLBACK=1 pi --version
```

## Known risk areas for future agents

- **Overlay/input ordering:** `TUI.addInputListener()` runs before focused overlay components. Any listener that consumes mouse/key input can starve overlays such as `/btw` or MCP popups.
- **Overlay rendering over a synthetic full-screen layout:** `InternalScrollbackLayout` returns exactly terminal-height-ish lines. If an overlay closes without forcing enough redraw/clear behavior, stale rows can appear duplicated.
- **Mouse mode side effects:** `pi-tui/dist/terminal.js` enables SGR mouse reporting when `PI_INTERNAL_SCROLLBACK=1`. Popup components that were never tested with mouse events may now receive or be blocked by them.
- **Package updates:** The edits are applied to installed generated JS/TS files. Future package updates can silently remove the patch.
