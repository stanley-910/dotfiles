# Cursor

AI-powered code editor.

## Installation

```bash
brew install --cask cursor
```

## Configuration

Configs: `~/.config/cursor/` (symlinked via stow)

Includes:
- `.cursorvimrc` - Vim keybindings
- `macos.code-profile` - backup export of the macOS Cursor profile

Import `macos.code-profile` through Cursor's profile import command. The export embeds stale `/Users/stanley` machine paths; they are harmless.

## Setup

1. Launch Cursor
2. Sign in to enable AI features and Settings Sync
3. Enable Vim mode in Settings if desired

## Settings Sync

Enable in Command Palette (`Cmd+Shift+P`) → "Settings Sync" to sync across machines.
