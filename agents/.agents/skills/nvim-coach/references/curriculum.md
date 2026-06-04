# Neovim Config Curriculum

The ordered spine of the coaching arc. Each phase = **read X**, then **do Y yourself** in the live config on the current branch. Go one phase per sitting. Phases build on each other — don't skip the Lua phase.

Run `:version` / `nvim --version` first so you know whether `news-0.11` or `news-0.12` applies. Two things are genuinely new and worth real attention: **built-in LSP config** (`vim.lsp.config` + `vim.lsp.enable`, 0.11) and the **built-in plugin manager** (`vim.pack`, 0.12).

The learner's current config is kickstart-derived on lazy.nvim, with `init.lua` doing options/keymaps/autocmds inline and `lua/config/` partially split. A recurring goal is to refactor toward a clean namespaced structure as understanding grows.

---

## Phase 0 — Orientation

**Read:** `:help nvim-from-vim` (~5m), `:help vim-differences` (~20m), `:help nvim-defaults` (~5m)

**Do:** Confirm where config lives — `:echo stdpath('config')`. List what Neovim already enables by default (so you stop re-setting it). No code yet; this phase is about not fighting the defaults.

**After:** You know where startup begins and stop applying stale Vim advice.

---

## Phase 1 — Lua, the cornerstone

**Read:** `:help lua-guide` (~60–90m — *the* doc, read top to bottom once, then keep open), then `:help lua-concepts` and skim `:help lua` for the `vim` module (~30m).

**Do:** Create the skeleton — a thin `init.lua` (`vim.loader.enable()` first line, set leader, then `require('<namespace>')`) and `lua/<namespace>/init.lua` that requires empty `options`/`keymaps`/`autocmds`/`plugins` submodules. Confirm Neovim starts clean with empty modules.

**After:** You can write real config in Lua, not paste it. You understand `require()` and the `lua/` search path.

*0.12 note:* `vim.diff` → `vim.text.diff` — watch for it in old snippets.

---

## Phase 2 — Options & keymaps

**Read:** `:help vim.opt` (within lua-guide), `:help options` (~30m), skim `:help option-list` as a lookup, `:help map.txt` + `:help vim.keymap.set()` (~30m).

**Do:** Fill `options.lua` (number/relativenumber, indentation, search, scrolloff, etc. — migrate the inline ones out of `init.lua`) and `keymaps.lua` (a handful of `vim.keymap.set` calls, each with a `desc`). Verify with `:verbose set <opt>?` and `:nmap <leader>...`.

**After:** Global vs buffer-local vs window-local is clear; you can bind any key in any mode to a Lua callback with a description.

*0.11 note:* setting a hidden/removed option now **errors** instead of silently no-op-ing.

---

## Phase 3 — Autocommands

**Read:** `:help autocmd` + `:help nvim_create_autocmd()` (~30m). Pay attention to augroups.

**Do:** Add `autocmds.lua` with a **cleared augroup** — e.g. highlight-on-yank (`vim.hl.on_yank`), trim trailing whitespace on `BufWritePre`. Re-source the file twice and prove the autocmd doesn't stack (`:autocmd <group>`).

**After:** You can run code on open/save/filetype without duplicate-autocmd bugs.

---

## Phase 4 — Plugins, the native way

**Read:** `:help packages` (~20m — the mechanism every manager builds on: `pack/*/start` vs `opt`, `:packadd`, `runtimepath`), then `:help vim.pack` (~30m — **NEW in 0.12**).

**Do:** On a scratch slice, install a colorscheme + one utility plugin via `vim.pack.add` in `plugins.lua`. Practice `:lua vim.pack.update()` (read the review buffer — `:write` confirms, `:quit` discards), then `vim.pack.del`. Inspect where it landed: `site/pack/core/opt/`.

**After:** You can manage plugins with zero third-party manager and understand what lazy.nvim was doing for you.

**Key facts:** API is `vim.pack.add/update/del/get`. Pin with `version = vim.version.range('1.0')` or a branch/tag. Lockfile at `$XDG_CONFIG_HOME/nvim/nvim-pack-lock.json` (don't hand-edit). Build hooks via a `PackChanged` autocmd registered **before** the `add()`. **No declarative lazy-loading** (`event`/`ft`/`cmd`/`keys`) — manual only, via a `load` callback or a FileType autocmd + `:packadd`. That single omission is the whole lazy-vs-pack decision.

---

## Phase 5 — Built-in LSP (the biggest change)

**Read:** `:help lsp` overview (~30m), `:help vim.lsp.config()` + `:help vim.lsp.enable()` (~40m — **NEW in 0.11, central in 0.12**), `:help lsp-attach` + `:help vim.lsp.buf` (~30m).

**Do:** Wire up **one** server end to end — e.g. `lua_ls` via an `lsp/lua_ls.lua` file that returns a table, then `vim.lsp.enable('lua_ls')`. Bind `hover`/`definition`/`rename` inside an `LspAttach` autocmd. Verify with `:checkhealth vim.lsp`. (The learner already has `vim.lsp.enable("lua_ls")` — this phase is about *understanding* and completing it: where does the `lsp/` dir live, what does the returned table need.)

**After:** You can wire a language server with **no framework**, and you read `nvim-lspconfig` as just a data repo of reusable `lsp/*.lua` files.

*Adopt this regardless of the plugin-manager decision.* Translate any old `require('lspconfig').xxx.setup{}` tutorial to `vim.lsp.config` / `vim.lsp.enable`.

---

## Phase 6 — Treesitter

**Read:** `:help treesitter` + `:help lua-treesitter` (~40m).

**Do:** Install `nvim-treesitter` aware of the **`main`-branch rewrite** — no `ensure_installed`, no `highlight = { enable = true }`. You call `vim.treesitter.start()` in a FileType autocmd and set `indentexpr` yourself. Install one parser, confirm highlighting, run `:checkhealth nvim-treesitter`. Treat as start-from-scratch.

**After:** You understand the engine that the plugin merely feeds parsers to.

*Schedule this on its own — it's the sharpest edge of 2025–26 and unrelated to the plugin-manager choice.*

---

## Phase 7 — Diagnostics & polish

**Read:** `:help diagnostic` + `:help diagnostic-api` / `vim.diagnostic.config` (~30m).

**Do:** `vim.diagnostic.config({ virtual_text = true, ... })` — **virtual text is off by default in 0.11**, so if you "see no inline errors," that's why. Wire diagnostic-jump keymaps. Then add the dev plugins one per sitting, each via `vim.pack.add`, reading each README rather than copying a distro: completion (**blink.cmp**), finder (**fzf-lua** or **telescope**), **oil.nvim** (already have it), **conform.nvim**, **gitsigns.nvim**.

**After:** You control how diagnostics look/move and have a real dev setup you built and understand.

*0.12 note:* the `float` jump option became `on_jump`.

---

## Capstone (ongoing, keep open)

- `:help news-0.11` / `:help news-0.12` — skim before trusting any older tutorial.
- `:help` + `:helpgrep` — the meta-skill that answers 90% of future questions yourself.

---

## Open decisions to revisit with the learner

1. **lazy.nvim vs vim.pack vs hybrid** — decide *after* Phases 4–5, once both models have been felt and startup measured. Community consensus for a mid-size lazy-loading config: "not yet / hybrid."
2. **Native LSP now** — yes, decouple from the manager decision (Phase 5).
3. **Completion:** blink.cmp (current default, Rust matcher / prebuilt binary; `fuzzy = { implementation = 'lua' }` to avoid the binary) vs nvim-cmp.
4. **Finder:** fzf-lua (speed) vs telescope (extensibility).
5. **Namespace name** for `lua/<namespace>/` — pick once, never refactor requires again.

---

## progress.md template (create in vault on session 1)

```markdown
---
tags:
  - index
up: "[[04-code/training-arc/neovim/neovim|neovim]]"
---

# Neovim Coaching Progress

- [ ] Phase 0 — Orientation
- [ ] Phase 1 — Lua skeleton
- [ ] Phase 2 — Options & keymaps
- [ ] Phase 3 — Autocommands
- [ ] Phase 4 — Plugins (vim.pack)
- [ ] Phase 5 — Built-in LSP
- [ ] Phase 6 — Treesitter
- [ ] Phase 7 — Diagnostics & polish

**Current phase:** 0
**Namespace chosen:** _tbd_
**Plugin-manager decision:** _deferred until after Phase 5_

## Session log
<!-- one line per session, newest first: YYYY-MM-DD — phase — headline -->
```
