# UWSM Configuration

Universal Wayland Session Manager (UWSM) configuration files for proper environment variable management.

## Structure

```
uwsm/.config/uwsm/
├── env           # Common variables for ALL Wayland sessions
└── env-hyprland  # Hyprland-specific variables (HYPR*, AQ_*)
```

## Files

### `env`
Environment variables common to all Wayland compositors managed by UWSM:
- Electron/Ozone flags (for Cursor, VS Code, etc.)
- GTK theme settings
- Qt platform settings
- Cursor theme/size

### `env-hyprland`
Hyprland-specific environment variables:
- `HYPR*` prefixed variables
- `AQ_*` (Aquamarine) prefixed variables
- GPU selection for multi-GPU setups

## Format

Both files use simple shell export syntax:
```bash
export KEY=VALUE
```

**Important**: No comments on the same line as exports.

## Usage with SDDM

1. In SDDM, select **"Hyprland (uwsm-managed)"** from the session menu
2. UWSM will source these files before starting Hyprland
3. All systemd services and applications inherit these variables

## Why Not hyprland.conf?

Environment variables in `hyprland.conf` are set **after** UWSM initializes the session, which can cause:
- Systemd services not getting the correct environment
- Race conditions with XDG Desktop Portal
- Inconsistent variable availability across applications

UWSM sources these files **before** starting the compositor, ensuring the entire session tree has the correct environment from the start.

## References

- [Arch Wiki - Hyprland UWSM](https://wiki.archlinux.org/title/Hyprland#Universal_Wayland_Session_Manager)
- [Hyprland Wiki - UWSM Configuration](https://wiki.hyprland.org/Getting-Started/Master-Tutorial/#launching-hyprland)


