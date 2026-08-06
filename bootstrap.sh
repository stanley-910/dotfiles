#!/usr/bin/env bash

# ============================================================================
# Dotfiles Bootstrap Script
# ============================================================================
# This script automates the setup of your development environment on a fresh
# macOS install. It installs Homebrew, all dependencies, clones necessary
# plugins, and symlinks your dotfiles using GNU Stow.
#
# Usage:
#   ./bootstrap.sh
#
# Prerequisites:
#   - macOS (tested on recent versions)
#   - Internet connection
#   - Git (usually pre-installed on macOS)
# ============================================================================

set -e  # Exit on any error

# Color codes for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

# Print colored info message
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print colored success message
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print colored warning message
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Print colored error message
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Walk a stow source directory, back up any real file already at the
# stow target. Apps like Karabiner-Elements and Zed auto-create config
# files on install/first launch, which then collide with stow.
# Mirrors stow's default ignores (README/LICENSE, .git).
#
# Critical: when a FULL_STOW dir is already stowed, the target path
# dereferences (via the parent dir symlink) directly to the source file
# in the repo. We must compare realpaths and skip those, otherwise we
# rename the actual dotfile sources.
backup_stow_conflicts() {
    local pkg=$1
    [ -d "$pkg" ] || return 0
    local timestamp src_real target_real
    timestamp=$(date +%Y%m%d_%H%M%S)
    while IFS= read -r src; do
        local rel="${src#"$pkg"/}"
        local target="$HOME/$rel"
        [ -e "$target" ] || continue
        # Already stowed (target resolves to same file as src) → skip
        src_real=$(readlink -f "$src" 2>/dev/null)
        target_real=$(readlink -f "$target" 2>/dev/null)
        [ "$src_real" = "$target_real" ] && continue
        # Symlink pointing elsewhere → leave it for stow to handle/report
        [ -L "$target" ] && continue
        # Real conflicting file → back it up
        mv "$target" "$target.backup.$timestamp"
        warn "Backed up conflicting $target → $target.backup.$timestamp"
    done < <(find "$pkg" -type f \
        ! -name 'README*' \
        ! -name 'LICENSE*' \
        ! -path '*/.git/*')
}

# ============================================================================
# Step 1: Check if Homebrew is installed
# ============================================================================

info "Checking for Homebrew installation..."

if ! command -v brew &> /dev/null; then
    warn "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    success "Homebrew installed successfully!"
else
    success "Homebrew already installed."
    info "Updating Homebrew..."
    brew update
fi

# ============================================================================
# Step 2: Install all dependencies from Brewfile
# ============================================================================

info "Installing dependencies from Brewfile..."

if [ -f "Brewfile" ]; then
    brew bundle install --verbose
    success "All Homebrew dependencies installed!"
else
    error "Brewfile not found in current directory!"
    exit 1
fi


# ============================================================================
# Step 3: Create necessary directories
# ============================================================================

info "Creating necessary directories..."

# ZSH plugin directory
mkdir -p ~/.zsh

# Config directories
mkdir -p ~/.config/scripts
mkdir -p ~/.config/tmux

# Local bin directory for tool-managed shims (uv, pipx, etc.). Custom scripts
# live in scripts/bin/ instead, which is added to $PATH directly from .zshenv
# and excluded from stow via scripts/.stow-local-ignore (so no ~/bin symlink).
mkdir -p ~/.local/bin

# XDG state dirs for relocated history/cache files (zsh history + zcompdump,
# less, python). Must exist before first shell — the programs won't create
# parent dirs, so compinit can't write its dump and history won't persist.
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"/{zsh,less,python}

# Agents directory for cross-platform skills
mkdir -p ~/.agents/skills

# Tmux plugin directory
mkdir -p ~/.tmux/plugins

success "Directories created!"

# ============================================================================
# Step 4: Clone ZSH plugins
# ============================================================================

info "Setting up ZSH plugins..."

# zsh-autosuggestions - suggests commands as you type
if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
    success "Installed zsh-autosuggestions"
else
    warn "zsh-autosuggestions already exists, skipping..."
fi

# zsh-syntax-highlighting - syntax highlighting for commands
if [ ! -d ~/.zsh/zsh-syntax-highlighting ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
    success "Installed zsh-syntax-highlighting"
else
    warn "zsh-syntax-highlighting already exists, skipping..."
fi

# fzf-tab - fuzzy finder for tab completion
if [ ! -d ~/.zsh/fzf-tab ]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
    success "Installed fzf-tab"
else
    warn "fzf-tab already exists, skipping..."
fi

# ============================================================================
# Step 5: Setup tmux and plugin manager
# ============================================================================


if [ -f ~/.config/tmux/tmux.conf ]; then
    tmux source-file ~/.config/tmux/tmux.conf
    success "Sourced tmux configuration file"
else
    warn "tmux configuration file not found"
fi


info "Setting up tmux plugin manager (tpm)..."
if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    success "Installed tmux plugin manager"
else
    warn "tmux plugin manager already exists, skipping..."
fi

# ============================================================================
# Step 6: Backup existing dotfiles (if any)
# ============================================================================

info "Checking for existing dotfiles to backup..."

# Files that commonly exist on a fresh laptop and would conflict with stow.
# Includes home-level dotfiles and files auto-created by apps (Claude Code,
# Zed, etc.) on first launch. Paths are relative to $HOME.
PATHS_TO_BACKUP=(
    ".zshrc"
    ".zprofile"
    ".zshenv"
    ".gitconfig"
    ".tmux.conf"
    ".claude/settings.json"
)

for target in "${PATHS_TO_BACKUP[@]}"; do
    if [ -f "$HOME/$target" ] && [ ! -L "$HOME/$target" ]; then
        # Flatten path separators so backups land beside the original
        BACKUP_NAME="$HOME/${target//\//_}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/$target" "$BACKUP_NAME"
        warn "Backed up existing $target to $BACKUP_NAME"
    fi
done

# ============================================================================
# Step 7: Symlink dotfiles using GNU Stow
# ============================================================================

info "Symlinking dotfiles with GNU Stow..."

# Simulate stow first to check for conflicts
info "Running stow simulation to check for conflicts..."
echo ""

# Directories that should be fully stowed (entire directory symlinked)
# These should NOT use --no-folding to create directory-level symlinks
FULL_STOW_DIRS=(cursor fastfetch ghostty git herdr jetbrains nvim scripts starship sioyek zsh)

# Directories that need selective file stowing (to avoid plugin/runtime pollution)
# These SHOULD use --no-folding to symlink individual files only
SELECTIVE_STOW_DIRS=(agents claude karabiner lazygit pi tmux yazi zed)

# Pre-emptively back up any real files at stow target paths. Necessary
# because brew bundle (step 2) may install apps (Karabiner-Elements, Zed,
# etc.) that auto-create config files before stow can symlink them in.
info "Scanning for stow conflicts and backing up existing files..."
for dir in "${FULL_STOW_DIRS[@]}" "${SELECTIVE_STOW_DIRS[@]}"; do
    backup_stow_conflicts "$dir"
done

# Simulate full directory stow (no --no-folding, creates directory-level symlinks)
for dir in "${FULL_STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Simulating stow for: $dir"
        stow --simulate -v "$dir" 2>&1 || true
    fi
done

# Simulate selective file stow (uses --no-folding to symlink files individually)
for dir in "${SELECTIVE_STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Simulating selective stow for: $dir (config files only)"
        stow --simulate --no-folding -v "$dir" 2>&1 || true
    fi
done

echo ""
warn "==================================================================="
warn "STOW SIMULATION COMPLETE - Please review output above"
warn "==================================================================="
echo ""
read -p "Do you want to proceed with symlinking? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Stow cancelled by user."
    exit 1
fi

info "Proceeding with actual stow..."

# Actually stow full directories (no --no-folding, creates directory-level symlinks)
for dir in "${FULL_STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Stowing: $dir"
        stow --restow -v "$dir"
    fi
done

# Stow selective directories (uses --no-folding to symlink files individually, avoids plugin pollution)
for dir in "${SELECTIVE_STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Stowing config files from: $dir"
        stow --restow --no-folding -v "$dir"
    fi
done

success "Dotfiles symlinked successfully!"

# ============================================================================
# Step 7b: Install shared skills for all supported agents
# ============================================================================

info "Installing shared skills..."

INSTALL_SKILL="agents/.agents/skills/install-skill/scripts/install-skill"
for skill_dir in agents/.agents/skills/*/; do
    [ -d "$skill_dir" ] || continue
    "$INSTALL_SKILL" "$(basename "$skill_dir")"
done

success "Shared skills installed and verified!"

# Install yazi plugins if yazi is installed
if command -v yazi &> /dev/null; then
    info "Installing yazi plugins..."
    ya pkg add dedukun/bookmarks || true
    success "Yazi plugin setup complete"
fi

# ============================================================================
# Step 8: Set ZSH as default shell (if not already)
# ============================================================================

info "Checking default shell..."

if [ "$SHELL" != "$(which zsh)" ]; then
    warn "Current shell is not ZSH. Changing default shell to ZSH..."
    chsh -s $(which zsh)
    success "Default shell changed to ZSH (restart terminal for changes to take effect)"
else
    success "ZSH is already the default shell"
fi

# ============================================================================
# Done! Print post-installation instructions
# ============================================================================

echo ""
echo "======================================================================"
success "Bootstrap completed successfully!"
echo "======================================================================"
echo ""
info "Next steps:"
echo ""
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo ""
echo "  2. Install tmux plugins:"
echo "     - Open tmux: tmux"
echo "     - Press: prefix + I (capital I) to install plugins"
echo "     - Default prefix is Ctrl+b"
echo ""
echo "  3. Grant permissions for GUI apps:"
echo "     - Karabiner-Elements: Needs Accessibility & Input Monitoring permissions"
echo "     - Open System Settings → Privacy & Security → Accessibility"
echo ""
echo "  4. Optional: Configure Git user"
echo "     git config --global user.name \"Your Name\""
echo "     git config --global user.email \"your.email@example.com\""
echo ""
echo "======================================================================"
info "For tool-specific setup info, check the README files in each subdirectory"
echo "======================================================================"
echo ""

