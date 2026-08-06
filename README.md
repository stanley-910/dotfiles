# dotfiles

Personal macOS development environment configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).

This repository contains configurations for shell, terminal, editors, and various development tools. It's designed for quick restoration of your dev environment on a fresh macOS install.

## Quick Start (Fresh macOS Install)

### 1. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Clone this repository

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. Run the bootstrap script

```bash
./bootstrap.sh
```

This will:
- Install all dependencies (CLI tools, GUI apps) via Homebrew
- Clone ZSH plugins and tmux plugin manager
- Create necessary directories
- Run stow simulation to check for conflicts
- Ask for confirmation before creating symlinks
- Symlink all dotfiles using GNU Stow
- Set ZSH as your default shell

### 4. Restart your terminal

```bash
# Source the new configuration
source ~/.zshrc

# Or restart your terminal application
```

## What's Included

### Shell & Terminal
- **ZSH** - Shell with plugins (autosuggestions, syntax highlighting, fzf-tab)
- **Starship** - Cross-shell prompt
- **Ghostty** - Modern GPU-accelerated terminal
- **tmux** - Terminal multiplexer

### Modern CLI Tools
- **eza** - Enhanced `ls` with git integration
- **bat** - Enhanced `cat` with syntax highlighting
- **fzf** - Fuzzy finder for files and commands
- **zoxide** - Smart directory jumper
- **ripgrep** - Fast code search
- **fd** - Modern `find` alternative
- **yazi** - Terminal file manager
- **tree** - Directory tree viewer

### Core Development Tools
- **Neovim** - Modern vim-based editor
- **Pi Coding Agent** - Local extensions/themes, including Starshipline, plan mode, and todos
- **FFmpeg** - Multimedia processing
- **jq** - JSON processor

### Editors & IDEs
- **Cursor** - AI-powered code editor
- **Zed** - Modern code editor
- **JetBrains** - IDE configurations (IdeaVim)

### System Tools
- **Karabiner-Elements** - Keyboard customization
- **fastfetch** - System information display
- **Sioyek** - Lightweight PDF viewer
- **Git** - Version control with custom config

## Manual Setup (Updating Existing Config)

If you're updating an existing setup or want more control:

```bash
# Install GNU Stow
brew install stow

# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# For existing config (adopt and restore), use the same package split as bootstrap.sh
for pkg in cursor fastfetch ghostty git herdr jetbrains nvim scripts starship sioyek zsh; do
  [ -d "$pkg" ] && stow --adopt "$pkg"
done
for pkg in agents claude karabiner lazygit pi tmux yazi zed; do
  [ -d "$pkg" ] && stow --adopt --no-folding "$pkg"
done
git restore .

# For fresh start (just symlink)
for pkg in cursor fastfetch ghostty git herdr jetbrains nvim scripts starship sioyek zsh; do
  [ -d "$pkg" ] && stow --restow "$pkg"
done
for pkg in agents claude karabiner lazygit pi tmux yazi zed; do
  [ -d "$pkg" ] && stow --restow --no-folding "$pkg"
done
```

## Post-Installation

### Install tmux plugins
1. Open tmux: `tmux`
2. Press `prefix + I` (capital I) to install plugins
3. Default prefix is `Ctrl+b`

### Configure Git (if needed)
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Grant GUI app permissions
- **Karabiner-Elements**: System Settings → Privacy & Security → Accessibility & Input Monitoring

## Directory Structure

Each subdirectory represents a tool:

```
dotfiles/
├── zsh/           # ZSH config (.zshrc, .zprofile, .zshenv)
├── git/           # Git config and global gitignore
├── tmux/          # Tmux config (plugins excluded via .stow-local-ignore)
├── yazi/          # Yazi config (plugins excluded)
├── karabiner/     # Karabiner config (backups excluded)
├── zed/           # Zed config (extensions excluded)
├── starship/      # Starship prompt config
├── pi/            # Pi coding agent extensions and themes
├── ghostty/       # Ghostty terminal config
├── cursor/        # Cursor editor settings
├── jetbrains/     # IdeaVim configuration
├── sioyek/        # Sioyek PDF viewer config
├── fastfetch/     # Fastfetch system info config
└── scripts/       # Custom utility scripts
```

View individual `README.md` files in each subdirectory for tool-specific details.

## How It Works

This repository uses **GNU Stow** to manage dotfiles:
- Each subdirectory contains configuration files in their expected structure
- Stow creates symlinks from `~` (home directory) to files in this repo
- Changes to files in this repo are immediately reflected in your system
- Commit and push changes to keep your dotfiles in sync across machines

## Customization

### Installing Optional Development Tools

Edit `Brewfile` and uncomment languages/tools you need, then run:
```bash
brew bundle install
```

### External Dependencies

Additional packages you may want are in `Brewfile.external`:
```bash
brew bundle install --file=Brewfile.external
```

This includes:
- Extra development languages (Python 3.12/3.13/3.14, Node, Crystal)
- Additional utilities (neovim, screen, nmap, rsync)
- macOS GUI apps (alt-tab, betterdisplay, monitorcontrol)
- Fonts (Hack Nerd Font)

Review and customize before installing.

## Important: Plugin Pollution Prevention

Some tools/packages (agents, claude, karabiner, lazygit, pi, tmux, yazi, zed) are stowed with `--no-folding` so runtime files, plugins, sessions, package installs, and caches stay in `$HOME` instead of being folded into this repo. This keeps your dotfiles clean - only configuration files are tracked.

## Troubleshooting

### Stow conflicts
If stow reports conflicts, backup the existing files:
```bash
mv ~/.zshrc ~/.zshrc.backup
stow --restow */
```

### ZSH not default shell
```bash
chsh -s $(which zsh)
```

### Homebrew not in PATH (Apple Silicon)
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

## License

Personal dotfiles - feel free to use, modify, or learn from them!
