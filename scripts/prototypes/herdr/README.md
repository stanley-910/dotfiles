# Herdr helper prototypes

Isolated Herdr ports of the tmux helper scripts. Nothing here is stowed, added
to `PATH`, or aliased. The prototype `git-menu` is bound to `prefix+g` in the
Herdr prototype config. The production scripts remain untouched.

## Run manually

From a Herdr pane:

```sh
~/dotfiles/scripts/prototypes/herdr/git-menu
~/dotfiles/scripts/prototypes/herdr/agent-link status
~/dotfiles/scripts/prototypes/herdr/agent-link path
```

The menu invokes only the copies beside it:

- `open_remote.sh`
- `open_ticket.sh`
- `agent-link`

## Context mapping

The ports resolve the caller in this order:

1. `HERDR_ACTIVE_PANE_CWD` / `HERDR_ACTIVE_PANE_ID` from a future Herdr custom command or popup.
2. `HERDR_PANE_ID` from a normal Herdr-managed pane process.
3. The process working directory when run outside Herdr.

`agent-link` replaces tmux's `@agent_worktree` pane option with the Herdr
`agent_worktree` metadata token reported by source `user:agent-link`. It uses
`herdr pane process-info` to retain the original per-pane process-tree lookup.

## Trial boundary

Do not add aliases, symlinks, or shell hooks while testing these copies. The
`prefix+g` binding is the only Herdr integration. Do not replace:

- `scripts/bin/agent-link`
- `scripts/.config/scripts/git-menu`
- `scripts/.config/scripts/open_remote.sh`
- `scripts/.config/scripts/open_ticket.sh`
