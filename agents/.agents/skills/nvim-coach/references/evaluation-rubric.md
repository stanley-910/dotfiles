# Neovim Config Evaluation Rubric

For a learner building a Neovim 0.12 config from first principles. Score each dimension 1–5: 5 = solid, 3 = needs work, 1 = missing/broken. The point is not just "does it work" — it's "did they understand it and write it the modern, idiomatic way."

---

## 1. Correctness

Does the config do what the task asked, and does Neovim load it without errors?

**5 — solid**
- `nvim --headless "+lua print('ok')" +qa` is clean (no errors/tracebacks)
- The option/keymap/autocmd/plugin actually takes effect (verifiable with `:verbose set`, `:nmap`, `:autocmd`, `:checkhealth`)
- Behaves as described, including the obvious edge (e.g. buffer-local where it should be)

**3 — needs work**
- Loads but the effect is partial or in the wrong scope (global where it should be buffer-local)
- Works for the demo but a related case is broken

**1 — missing**
- Throws on startup, or doesn't do the task

---

## 2. Idiomatic API (0.11+)

Is it written the modern way, not a pre-0.11 pattern copied off a blog?

**5 — solid**
- `vim.keymap.set` (not `vim.api.nvim_set_keymap` / `:map`), with `desc`
- `vim.opt` / `vim.o` / `vim.bo` / `vim.wo` chosen correctly for scope
- `vim.api.nvim_create_autocmd` with an explicit `group`
- LSP via `vim.lsp.config` + `vim.lsp.enable` + `lsp/<server>.lua` — **not** `require('lspconfig').x.setup{}`
- Plugins via `vim.pack.add` (when on the native path) — not hand-rolled `:packadd` plumbing
- `vim.version.range(...)` for pinning

**3 — needs work**
- Mostly modern but one legacy call slipped in (`nvim_set_keymap`, `vim.cmd('set ...')` for something with a Lua API)
- `vim.o` where `vim.bo`/`vim.wo` was the right scope

**1 — missing**
- Pre-0.11 throughout (vimscript `:map`/`:set`, `lspconfig.setup{}`)

---

## 3. Structure & load order

Right code in the right file, loaded in the right order.

**5 — solid**
- Lives in the correct file (`options.lua` / `keymaps.lua` / `autocmds.lua` / `plugins.lua` / `lsp/<server>.lua` / `after/`)
- Config Lua under a single `lua/<namespace>/` to avoid module-name collisions with plugins
- `vim.g.mapleader` set **before** any mapping and before the plugin manager loads
- `require()` order respects dependencies; overrides go in `after/`
- Understands that `require()` caches — re-source won't pick up edits without a restart or cache clear

**3 — needs work**
- Works but code is in a questionable place (e.g. options inline in `init.lua` when a module exists)
- Flat `lua/options.lua` risking a plugin collision

**1 — missing**
- mapleader after mappings; wrong load order causes the bug; everything dumped in one file with no reasoning

---

## 4. Docs grounding

Did they actually read `:help`, and can they explain *why* from it?

**5 — solid**
- Can name the `:help` tag that documents what they wrote
- Choices trace to the doc, not cargo-culted from a distro
- Used `:help`/`:helpgrep` to answer their own question during the task

**3 — needs work**
- Got it working but can't cite where the doc covers it
- Copied a pattern without reading the surrounding `:help` caveats

**1 — missing**
- Pasted from memory/a blog with no `:help` engagement; can't explain why it works

---

## 5. Robustness

Does it survive re-sourcing, missing plugins, and odd buffers?

**5 — solid**
- Autocmds in a **cleared** augroup (`nvim_create_augroup(..., { clear = true })`) — no stacking on re-source
- Optional `require()`s guarded with `pcall` where a plugin might be absent
- Buffer-local settings/keymaps scoped with `buffer = bufnr` (e.g. inside `LspAttach`)
- No errors when a feature/plugin isn't present

**3 — needs work**
- Autocmd not grouped (stacks), or a `require` that hard-fails when a plugin is missing

**1 — missing**
- Re-sourcing visibly breaks things; global keymaps where buffer-local was needed

---

## 6. Readability

Is it clear and maintainable?

**5 — solid**
- `desc` on keymaps and autocmds (shows in which-key / `:map`)
- Descriptive names; brief comments only on non-obvious choices (not line narration)
- Consistent style; `stylua`-clean if available
- Clear top-to-bottom flow within each module

**3 — needs work**
- Correct but hard to follow; magic values unexplained; missing `desc`s

**1 — missing**
- Cryptic, uncommented, inconsistent

---

**Note for this learner:** they're migrating off a kickstart/lazy.nvim base. Reward moving inline `init.lua` config into proper modules and adopting the native 0.11/0.12 APIs even when the old way still "works" — the whole arc is about understanding, not just function.
