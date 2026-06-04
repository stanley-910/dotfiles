# Silly Mistakes

Recurring, avoidable mistakes the learner has hit. When one shows up again, call it out immediately with light shame (no emojis) before answering, and increment the session count. Seeded with the classic Neovim-config traps; add new ones as they appear.

Format: `#<n> — <short name>: <description> — <the fix>`

---

#1 — **mapleader after mappings**: setting `vim.g.mapleader` *after* defining a `<leader>` keymap (or after the plugin manager loads). The map captures the old leader. — Set `mapleader`/`maplocalleader` at the very top of `init.lua` (or first in `options.lua`), before any mapping or plugin load.

#2 — **legacy keymap API**: using `vim.api.nvim_set_keymap` / `:map`. — Use `vim.keymap.set` (defaults to `noremap`, takes a Lua callback and a `desc`).

#3 — **autocmd not in a cleared augroup**: defining `nvim_create_autocmd` with no group, so it stacks every re-source. — Wrap in `vim.api.nvim_create_augroup('Name', { clear = true })` and pass `group =`.

#4 — **flat lua/ module collision**: `lua/options.lua` (or `keymaps`, `utils`) at the top level, which can collide with a plugin's module of the same name on the runtimepath. — Nest everything under one `lua/<namespace>/`.

#5 — **require() cache surprise**: editing a Lua module and expecting `:source %` / re-require to pick it up. `require` caches by module name. — Restart Neovim, or `package.loaded['<mod>'] = nil` before re-requiring.

#6 — **vim.opt vs vim.o vs vim.bo/wo**: using `vim.o` for a buffer/window-local option that should be `vim.bo`/`vim.wo`, or trying `vim.o.listchars = {...}` (a table) when `vim.o` wants a string. — `vim.opt` for list/map-style options and method access (`:append`/`:remove`); `vim.bo`/`vim.wo` for buffer/window scope.

#7 — **old LSP setup pattern**: `require('lspconfig').lua_ls.setup{}` copied from a pre-0.11 tutorial. — `vim.lsp.config('lua_ls', {...})` (or an `lsp/lua_ls.lua` file) + `vim.lsp.enable('lua_ls')`.

#8 — **"LSP is broken, no inline errors"**: expecting virtual-text diagnostics out of the box. Virtual text is **off by default** since 0.11. — `vim.diagnostic.config({ virtual_text = true })`.

#9 — **expecting vim.pack lazy-loading**: looking for `event`/`ft`/`cmd`/`keys` like lazy.nvim. `vim.pack` has no declarative lazy-loading. — Manual deferral via a `load` callback or a FileType autocmd + `:packadd`, or stay on lazy.nvim for that.

#10 — **trusting a stale tutorial**: applying advice that predates 0.11/0.12 (treesitter `ensure_installed`/`highlight.enable`, `vim.diff`, lspconfig setup). — Check `:help news-0.11` / `:help news-0.12` first; treat the doc as ground truth over blogs.

#11 — **skipping :help**: pasting from memory/web instead of reading the `:help` tag for the thing being configured. — Open the tag, read the section, then write it. The doc almost always has the answer.
