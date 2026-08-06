# JetBrains IDEs

IdeaVim configuration for JetBrains IDEs.

## Installation

Install IDEs as needed:

```bash
brew install --cask intellij-idea-ce  # or intellij-idea, pycharm-ce, webstorm, etc.
```

## IdeaVim Plugin

1. Open IDE → Settings → Plugins
2. Search "IdeaVim" and install
3. Restart IDE

## Configuration

Config: `~/.ideavimrc` (symlinked via stow)

Loaded automatically when IdeaVim is enabled.

## Settings Sync

Use built-in Settings Sync: File → Manage IDE Settings → Settings Sync

## Settings Archives

The tracked `intellij/settings.zip` and `webstorm/settings.zip` files are backup exports of IntelliJ IDEA and WebStorm settings.

Restore an archive through File → Manage IDE Settings → Import Settings.

The archives embed a `/Users/stanley/.m2` path macro. It is a stale, harmless artifact; the IDE re-derives the path on import.
