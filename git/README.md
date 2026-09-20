# Git Configuration

Global git settings and ignore patterns.

## Files

Symlinked via stow:
- `~/.gitconfig` - Git configuration
- `~/.gitignore_global` - Global gitignore patterns

## Configuration Includes

- User settings (name/email - customize these)
- Git LFS support
- Color UI
- Rerere enabled
- Branch sorting by commit date
- Auto setup remote on push
- Global gitignore (`.DS_Store`, IDE files, etc.)

## Customize

Edit user details:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Or edit `~/.gitconfig` directly.


## Global hooks

`core.hooksPath = ~/.githooks` (stowed from `git/.githooks/`). `commit-msg`
rejects any commit whose message carries an AI attribution trailer
(`Co-Authored-By: Claude …`, `Generated with Claude Code`, and similar), then
delegates to the repository's own `.git/hooks/commit-msg` if one exists. A repo
that sets its own `core.hooksPath` (husky, lefthook) bypasses this hook.
