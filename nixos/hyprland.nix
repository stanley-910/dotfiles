# ==============================================================================
# Hyprland Configuration - Minimal Install
# ==============================================================================
# Basic Hyprland installation. Add more features incrementally.
# Import this in configuration.nix via: imports = [ ./hyprland.nix ];

{ config, lib, pkgs, rose-pine-hyprcursor, ... }:

{
  # --------------------------------------------------------------------------
  # Enable Hyprland with UWSM
  # --------------------------------------------------------------------------
  programs.hyprland = {
    enable = true;
    # UWSM provides better systemd integration for Wayland compositors
    # When using a display manager (SDDM), select "Hyprland (uwsm-managed)"
    withUWSM = true;
    xwayland.enable = true;  # Enable XWayland for X11 app compatibility
  };

  # --------------------------------------------------------------------------
  # Display Manager - SDDM
  # --------------------------------------------------------------------------
  # SDDM has excellent Wayland support and works well with UWSM
  # It will present "Hyprland (uwsm-managed)" as a session option
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;  # Enable Wayland support for SDDM itself
  };

  # --------------------------------------------------------------------------
  # Enable seat management for proper input device handling
  # --------------------------------------------------------------------------
  # Seatd provides seat management, allowing non-root users to access input
  # devices like keyboards, mice, and touchpads. This is critical for Wayland
  # compositors like Hyprland to properly handle input devices on re-login.
  services.seatd = {
    enable = true;
    # User will be added to 'seat' group automatically via extraGroups
  };

  # --------------------------------------------------------------------------
  # Session environment variables
  # --------------------------------------------------------------------------
  # Force Wayland session type for proper session management
  environment.sessionVariables = {
    XDG_SESSION_TYPE = "wayland";
  };

  # --------------------------------------------------------------------------
  # Laptop docking configuration
  # --------------------------------------------------------------------------
  # Allow system to stay awake with lid closed ONLY when external monitors connected
  # This enables "docked mode" - close lid and use only external displays
  # Will still suspend normally when on battery or AC without external monitors
  services.logind.settings = {
    Login = {
      HandleLidSwitchDocked = "ignore";  # Don't suspend when external monitors detected
      # HandleLidSwitch defaults to "suspend" - will suspend on battery
      # HandleLidSwitchExternalPower defaults to "suspend" - will suspend on AC without dock
    };
  };

  # Enable USB devices to wake the system from suspend
  # This allows keyboard/mouse to wake your ThinkPad without opening the lid
  services.udev.extraRules = ''
    # Enable wake for all USB devices (keyboards, mice, hubs)
    # Change "enabled" to "disabled" for specific devices if they cause unwanted wakes
    ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled"
  '';

  # --------------------------------------------------------------------------
  # Essential Hyprland packages
  # --------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Multimedia controls for laptop function keys
    brightnessctl  # Control screen brightness (requires video group)
    playerctl      # Control media players (play/pause/next/prev)
    nwg-displays   # Display manager for Hyprland
    libnotify      # Notification library for Hyprland
  ] ++ [
    # Rose Pine Hyprcursor - from flake input (not in nixpkgs)
    # This provides the proper Hyprcursor format theme
    rose-pine-hyprcursor.packages.${pkgs.system}.default
  ];

  # --------------------------------------------------------------------------
  # HyprDynamicMonitors Service
  # --------------------------------------------------------------------------
  # Automatic monitor configuration based on connected displays and lid state.
  # Replaces shikane with Hyprland-native monitor profile management.
  # Config managed via stow at: ~/.config/hyprdynamicmonitors/
  # This allows the TUI to create/edit profiles directly
  services.hyprdynamicmonitors = {
    enable = true;
    # Run as user service (better for per-user Hyprland sessions)
    mode = "user";
    # Don't install NixOS-managed config - user manages via stow
    installExamples = false;
    # Enable lid event detection for open/closed lid profile switching
    # Disable power events since we don't use AC/battery conditions
    extraFlags = [ "--enable-lid-events" "--disable-power-events" ];
  };
}
