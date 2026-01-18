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
  # Essential Hyprland packages
  # --------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Multimedia controls for laptop function keys
    brightnessctl  # Control screen brightness (requires video group)
    playerctl      # Control media players (play/pause/next/prev)
  ] ++ [
    # Rose Pine Hyprcursor - from flake input (not in nixpkgs)
    # This provides the proper Hyprcursor format theme
    rose-pine-hyprcursor.packages.${pkgs.system}.default
  ];
}
