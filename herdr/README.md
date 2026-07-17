# Herdr prototype

**Throwaway evaluation package.** Delete or absorb it after deciding whether Herdr should replace tmux for the core multiplexer workflow.

Question being tested: can Herdr replace core tmux navigation, persistence, mouse/copy behavior, and agent visibility without first porting the tmux-dependent scripts?

## Run

```sh
herdr
```

The prototype intentionally does not modify or bind:

- `tmux-sessionizer`
- `git-menu`
- `agent-link`
- Neovim edge navigation
- `fzf-tab`'s tmux popup
- Pi extensions

The official installer placed the prototype binary at `~/.local/bin/herdr`.

## Remove

Stop any running prototype session, unstow the package, and remove the standalone binary:

```sh
herdr server stop
stow -D --no-folding herdr
rm ~/.local/bin/herdr
```
