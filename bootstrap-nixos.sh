#!/usr/bin/env bash

# ==============================================================================
# NixOS Dotfiles Bootstrap Script
# ==============================================================================
# This script sets up user-level configurations on NixOS.
# Unlike macOS, NixOS handles most plugins declaratively via configuration.nix.
# This script only sets up:
#   - fzf-tab (not available as NixOS module)
#   - tmux plugin manager (tpm)
#   - User dotfile symlinks via stow
#
# Prerequisites:
#   - NixOS with packages installed via configuration.nix
#   - Git (installed via nix)
#   - Stow (installed via nix)
#
# Usage:
#   ./bootstrap-nixos.sh
# ==============================================================================

set -e  # Exit on any error

# Color codes for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Step 1: Check if running on NixOS
# ==============================================================================

info "Checking if running on NixOS..."

if [[ ! -f /etc/NIXOS ]]; then
    warn "This script is designed for NixOS. Use bootstrap.sh for macOS."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Aborted."
        exit 1
    fi
fi

success "Running on NixOS."

# ==============================================================================
# Step 2: Create necessary directories
# ==============================================================================

info "Creating necessary directories..."

# ZSH plugin directory (for fzf-tab only - autosuggestions/syntax-highlighting are NixOS-managed)
mkdir -p ~/.zsh

# Config directories
mkdir -p ~/.config/tmux
mkdir -p ~/.config/ghostty
mkdir -p ~/.config/starship

# Tmux plugin directory
mkdir -p ~/.tmux/plugins

# Local bin directory for custom scripts
mkdir -p ~/.local/bin

success "Directories created!"

# ==============================================================================
# Step 3: Clone fzf-tab (not managed by NixOS)
# ==============================================================================

info "Setting up fzf-tab plugin..."

if [ ! -d ~/.zsh/fzf-tab ]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
    success "Installed fzf-tab"
else
    warn "fzf-tab already exists, skipping..."
fi

# ==============================================================================
# Step 4: Setup tmux plugin manager
# ==============================================================================

info "Setting up tmux plugin manager (tpm)..."

if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    success "Installed tmux plugin manager"
else
    warn "tmux plugin manager already exists, skipping..."
fi

# ==============================================================================
# Step 5: Backup existing dotfiles (if any)
# ==============================================================================

info "Checking for existing dotfiles to backup..."

DOTFILES_TO_BACKUP=(".zshrc" ".gitconfig")

for dotfile in "${DOTFILES_TO_BACKUP[@]}"; do
    if [ -f "$HOME/$dotfile" ] && [ ! -L "$HOME/$dotfile" ]; then
        BACKUP_NAME="$HOME/${dotfile}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/$dotfile" "$BACKUP_NAME"
        warn "Backed up existing $dotfile to $BACKUP_NAME"
    fi
done

# ==============================================================================
# Step 6: Symlink dotfiles using GNU Stow
# ==============================================================================

info "Symlinking dotfiles with GNU Stow..."

# Change to dotfiles directory
cd ~/dotfiles

# Simulate stow first to check for conflicts
info "Running stow simulation to check for conflicts..."
echo ""

# Directories to stow (NixOS-compatible configs)
STOW_DIRS=(zsh tmux ghostty starship scripts git nvim hypr)

# Simulate stow
for dir in "${STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Simulating stow for: $dir"
        stow --simulate -v "$dir" 2>&1 || true
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

for dir in "${STOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        info "Stowing: $dir"
        stow --restow -v "$dir"
    fi
done

success "Dotfiles symlinked successfully!"

# ==============================================================================
# Step 7: Set up NixOS symlinks for /etc/nixos (requires sudo)
# ==============================================================================

echo ""
info "Setting up NixOS configuration symlinks..."
echo ""
warn "The following commands require sudo to link /etc/nixos to your dotfiles:"
echo ""
echo "  sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup"
echo "  sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix.backup"
echo "  sudo ln -s ~/dotfiles/nixos/configuration.nix /etc/nixos/configuration.nix"
echo "  sudo ln -s ~/dotfiles/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix"
echo ""
read -p "Do you want to run these commands now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup existing configs
    if [ -f /etc/nixos/configuration.nix ] && [ ! -L /etc/nixos/configuration.nix ]; then
        sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup
        success "Backed up /etc/nixos/configuration.nix"
    fi
    if [ -f /etc/nixos/hardware-configuration.nix ] && [ ! -L /etc/nixos/hardware-configuration.nix ]; then
        sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix.backup
        success "Backed up /etc/nixos/hardware-configuration.nix"
    fi
    
    # Create symlinks
    sudo ln -sf ~/dotfiles/nixos/configuration.nix /etc/nixos/configuration.nix
    sudo ln -sf ~/dotfiles/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
    
    success "NixOS configuration symlinks created!"
    echo ""
    info "Now run: sudo nixos-rebuild switch"
else
    warn "Skipped NixOS symlinks. Run the commands manually when ready."
fi

# ==============================================================================
# Done! Print post-installation instructions
# ==============================================================================

echo ""
echo "======================================================================"
success "Bootstrap completed successfully!"
echo "======================================================================"
echo ""
info "Next steps:"
echo ""
echo "  1. If you haven't already, create NixOS symlinks (see commands above)"
echo ""
echo "  2. Apply NixOS configuration:"
echo "     sudo nixos-rebuild switch"
echo ""
echo "  3. Restart your terminal or run: source ~/.zshrc"
echo ""
echo "  4. Install tmux plugins:"
echo "     - Open tmux: tmux"
echo "     - Press: prefix + I (capital I) to install plugins"
echo "     - Default prefix is Alt+Space (as configured)"
echo ""
echo "======================================================================"

