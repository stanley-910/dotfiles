# Neovim config

Personal Neovim configuration, stowed to `~/.config/nvim`.

## System dependencies

Install these outside Neovim before bootstrapping plugins:

```sh
brew install tree-sitter-cli
```

`nvim-treesitter` on the `main` branch requires the `tree-sitter` CLI to build parsers. The Homebrew `tree-sitter` formula only installs the library; the executable comes from `tree-sitter-cli`.

## QuickBind prototype

`config.quickbind` is a prototype for Obsidian Spacekeys-style quick binding on top of Neovim keymaps and which-key.

Generated bindings live in:

```text
lua/config/quickbind_generated.lua
```

Hand-written keymaps stay in:

```text
lua/config/keymap.lua
```

The generated file is a small manifest, not regular keymap source. For example:

```lua
binds = {
  { lhs = "<leader>L", modes = { "n", "x" }, action = "command.Lazy", desc = "Lazy" },
}
```

`lhs` is the key sequence passed to `vim.keymap.set()` as the left-hand side. `action` is a stable action id that QuickBind resolves at startup.

### Commands

```vim
:QuickBind
:QuickBind!
:QuickBindList
:QuickBindDelete
:QuickBindEdit
:QuickBindReload
```

Leader helpers:

```text
<leader>kb  Quick bind action
<leader>kd  Delete generated quickbind
<leader>ke  Edit generated quickbinds
<leader>kl  List generated quickbinds
<leader>kr  Reload generated quickbinds
```

### Useful doc anchors

Read these when changing the prototype:

```vim
:help vim.keymap.set()
:help vim.ui.select()
:help vim.ui.input()
:help maparg()
:help mapcheck()
:help nvim_create_user_command()
:help which-key.nvim-which-key-mappings
```

### Stress-test checklist

#### 1. Action picker

Run:

```vim
:QuickBind
```

or:

```text
<leader>kb
```

Test:

- picker opens
- fuzzy search works
- `<Esc>` cancels without writing anything
- selecting an action advances to the mode prompt

Good searches:

```text
Lazy
file.find
grep
lsp
diagnostic
git
quickbind
```

Action sources currently include curated actions, existing described keymaps, user commands such as `:Lazy`, and QuickBind self-management actions.

#### 2. Direct query binding

Run:

```vim
:QuickBind command.Lazy
:QuickBind file.grep
```

If the query matches one action, QuickBind skips the big picker and goes straight to mode/key prompts.

#### 3. Mode parsing

At the mode prompt, test:

```text
n
x
nx
n,x
i
t
c
```

Expected behavior:

- `nx` creates both normal and visual mappings
- `n,x` also works
- empty input uses the action default
- invalid mode like `q` warns/errors and does not write

Verify with:

```vim
:verbose nmap <leader>L
:verbose xmap <leader>L
```

#### 4. Key input normalization

At the key prompt, these should normalize to `<leader>L`:

```text
L
SPC L
leader L
<leader>L
<Space>L
```

Raw non-leader keys should remain raw:

```text
<C-l>
<M-l>
```

#### 5. Group creation

Bind a deeper sequence:

```text
fg
SPC f g
```

If `<leader>f` is not already a group, QuickBind should prompt:

```text
Description for group SPC f:
```

Generated output should include:

```lua
groups = {
  { lhs = "<leader>f", desc = "find" },
}
```

Also test nested paths such as:

```text
abc
```

Expected prompts:

```text
SPC a
SPC a b
```

#### 6. Conflict detection

Exact conflict:

- bind something to `<leader>L`
- try binding another action to `<leader>L`
- QuickBind should ask whether to override
- cancel should leave the generated file unchanged

Prefix conflict:

- if `<leader>L` is a leaf mapping, try binding `Lx`
- QuickBind should block because `<leader>L` cannot be both a command and a prefix group

Which-key-only group metadata should not count as a real leaf conflict.

#### 7. Force override

Run:

```vim
:QuickBind!
:QuickBind! command.Lazy
```

Expected:

- exact-conflict confirmation is skipped
- prefix conflicts are still blocked

#### 8. Persistence

After binding something, inspect:

```vim
:e ~/.config/nvim/lua/config/quickbind_generated.lua
```

Restart Neovim and verify:

```vim
:verbose nmap <leader>L
:verbose xmap <leader>L
```

Expected: mappings still exist after restart.

#### 9. Command fallback persistence

This protects persisted command actions from command-registry timing issues.

If generated contains:

```lua
{ lhs = "<leader>L", modes = { "n", "x" }, action = "command.Lazy", desc = "Lazy" }
```

then restart Neovim and verify:

```vim
:verbose nmap <leader>L
:verbose xmap <leader>L
```

Expected:

- no `[quickbind] skipping ... missing action command.Lazy`
- mapping resolves to `<cmd>Lazy<CR>` even if `:Lazy` was not visible when QuickBind built its action registry

#### 10. QuickBindList

Run:

```vim
:QuickBindList
```

or:

```text
<leader>kl
```

Expected:

- opens a scratch markdown buffer
- shows generated file path
- shows groups and binds
- does not modify files

#### 11. QuickBindEdit

Run:

```vim
:QuickBindEdit
```

or:

```text
<leader>ke
```

Expected: opens `quickbind_generated.lua` for inspection/manual edits.

After manual edits, run:

```vim
:QuickBindReload
```

#### 12. QuickBindReload

Run:

```vim
:QuickBindReload
```

or:

```text
<leader>kr
```

Expected:

- reloads generated file
- reapplies keymaps
- warns but does not crash if a non-command action id is missing

Deliberate missing-action test:

```lua
{ lhs = "<leader>Z", mode = "n", action = "does.not.exist", desc = "Bad action" },
```

Then run:

```vim
:QuickBindReload
```

Expected warning:

```text
[quickbind] skipping <leader>Z: missing action does.not.exist
```

#### 13. QuickBindDelete

Run:

```vim
:QuickBindDelete
```

or:

```text
<leader>kd
```

Expected:

- picker shows generated binds
- cancel does nothing
- delete removes from generated file
- current-session generated keymap is deleted

For multi-mode binds, verify both are gone:

```vim
:verbose nmap <leader>L
:verbose xmap <leader>L
```

#### 14. Existing keymap rebinding

Search for existing keymaps by description:

```text
Rebind
Find files
Format buffer
Toggle terminal
```

Expected:

- string RHS mappings can be rebound and persisted well
- Lua callback mappings work when represented by stable action ids
- callback-only existing maps are an area to watch carefully during prototype testing

#### 15. Lua function actions

Test:

```vim
:QuickBind file.find
:QuickBind file.grep
:QuickBind lsp.format
:QuickBind diagnostic.line
```

Expected:

- action persists by id
- restart still works because these ids live in `quickbind_actions.lua`

#### 16. Missing plugin actions

Test plugin-backed actions:

```vim
:QuickBind git.preview_hunk
:QuickBind file.oil
```

Expected:

- mapping is created
- pressing it requires/loads the plugin or warns clearly
- no stack trace if plugin is unavailable

#### 17. Cancel behavior

Cancel at each step:

- action picker
- mode prompt
- key prompt
- group description prompt
- override confirmation
- delete confirmation

Expected: no partial bind is written.

#### 18. Generated file corruption

Temporarily break the generated file:

```lua
return {
```

Then restart or run:

```vim
:QuickBindReload
```

Expected:

- warning
- no startup death
- generated binds do not apply until the file is fixed

#### 19. which-key integration

After making groups/binds, press:

```text
<leader>
```

Expected:

- `<leader>k` group shows
- generated groups show
- generated binds show descriptions

Also run:

```vim
:checkhealth which-key
```

#### 20. Startup cleanliness

After stress tests, inspect:

```vim
:messages
```

Watch for:

```text
[quickbind] skipping
stack traceback
cannot resume running coroutine
```

Expected: none, except deliberate missing-action tests.

### Recommended manual stress sequence

```vim
:QuickBind command.Lazy
" modes: nx
" key: L

:QuickBind file.grep
" modes: n
" key: fg
" group SPC f: find

:QuickBind lsp.format
" modes: n
" key: lf
" group SPC l: lsp

:QuickBindList
:verbose nmap <leader>L
:verbose xmap <leader>L
:verbose nmap <leader>fg
:verbose nmap <leader>lf
```

Restart Neovim, then run the same `:verbose` checks again.

## Dropbar notes

`dropbar.nvim` is configured in:

```text
lua/plugins/dropbar.lua
```

The plugin is loaded eagerly because its own setup path attaches the winbar via events such as `FileType` and `LspAttach`. Loading it only from a keymap can be too late and can leave `_G.dropbar` nil when calling `dropbar.api` functions directly.

### Dropbar doc anchors

```vim
:help dropbar
:help dropbar.api.pick()
:help dropbar.api.select_next_context()
:help 'winbar'
```

### Dropbar smoke checks

```vim
:lua =vim.g.loaded_dropbar
:lua =type(_G.dropbar)
:lua =vim.wo.winbar
:lua =require("dropbar.utils.bar").get_current()
:verbose nmap ];
:verbose nmap [;
:verbose nmap <leader>;
```

Behavioral checks:

- open a Lua file with treesitter available
- move cursor into nested functions/tables
- confirm winbar changes
- press `[;`
- press `];`
- press `<leader>;`
- try a Markdown file
- try a help buffer, where dropbar usually should not attach
- try a large/random file, where dropbar may not attach by design

If `require("dropbar.utils.bar").get_current()` returns nil in a normal Lua/Markdown buffer, check:

```vim
:lua =vim.bo.filetype
:lua =pcall(vim.treesitter.get_parser, 0)
:lua =vim.lsp.get_clients({ bufnr = 0, method = "textDocument/documentSymbol" })
:verbose setlocal winbar?
```

Dropbar's default `bar.enable()` refuses to attach when:

- buffer/window is invalid
- window is special
- `winbar` is already set
- filetype is `help`
- file is larger than 1 MiB
- no markdown/tree-sitter/LSP-symbol source is available
