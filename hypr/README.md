# Hyprland Configuration

Minimal Hyprland Wayland compositor configuration.

## Current Status

**Minimal install** - Just Hyprland and kitty as backup terminal.

## Key Bindings

### Basic
- `Super + Enter` - Open Ghostty terminal
- `Super + Shift + Enter` - Open Kitty terminal (backup)
- `Super + Q` - Close window
- `Super + Shift + E` - Exit Hyprland
- `Super + F` - Fullscreen
- `Super + V` - Toggle floating

### Window Navigation
- `Super + h/j/k/l` - Vim-style focus movement
- `Super + Arrow Keys` - Arrow key focus movement

### Workspaces
- `Super + [1-9]` - Switch to workspace
- `Super + Shift + [1-9]` - Move window to workspace
- `Super + Mouse Scroll` - Cycle workspaces

### System
- `Super + Shift + S` - Suspend (sleep)

## Installation

1. Stow the config:
```bash
cd ~/dotfiles
stow hypr
```

2. Rebuild NixOS:
```bash
sudo nixos-rebuild switch
```

3. Log out and select Hyprland at login screen

## To Add Later

We'll add these incrementally:
- [ ] App launcher (wofi/rofi)
- [ ] Status bar (waybar)
- [ ] Notifications (dunst/mako)
- [ ] Screenshots
- [ ] Audio control
- [ ] Brightness control
- [ ] Wallpaper
