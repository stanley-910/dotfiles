# Herdr

Configuration for the Herdr terminal workspace multiplexer.

## Run

```sh
herdr
```

The configuration does not modify or bind:

- `tmux-sessionizer`
- `git-menu`
- `agent-link`
- Neovim edge navigation
- `fzf-tab`'s tmux popup
- Pi extensions

The official installer places the binary at `~/.local/bin/herdr`.

## Uninstall

Stop any running session, unstow the package, and remove the standalone binary:

```sh
herdr server stop
stow -D herdr
rm ~/.local/bin/herdr
```
