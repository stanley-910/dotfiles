# Scripts

Custom utility scripts, split into two locations by purpose.

## `bin/` — global commands (on `$PATH`)

Added to `$PATH` directly from `zsh/.zshenv`:

```sh
export PATH="$HOME/dotfiles/scripts/bin:$PATH"
```

This points straight at the repo, so it is **not** stowed (see
`.stow-local-ignore`). To add a global command:

```sh
nvim ~/dotfiles/scripts/bin/mytool   # no extension → clean command name
chmod +x ~/dotfiles/scripts/bin/mytool
mytool                               # runnable from anywhere, no restow
```

Current: `afk-run`, `align`, `open-obsidian.sh`.

## `.config/scripts/` — config-invoked helpers (stowed)

Scripts called by full path from shell config rather than typed as commands —
e.g. `tmux-sessionizer` (bound to `^f` in `.zshrc`) and `.lessfilter` (used via
`$LESSOPEN`). Stowed to `~/.config/scripts/` like the rest of the package.

After adding a file here, re-establish the symlink:

```sh
stow --restow scripts   # run from ~/dotfiles
```
