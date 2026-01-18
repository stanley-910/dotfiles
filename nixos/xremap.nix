# ==============================================================================
# xremap Configuration - Key Remapping for Wayland/X11
# ==============================================================================
# xremap allows remapping keys globally or per-application.
# Great for customizing keyboard layouts, creating custom shortcuts, etc.
# Import this in configuration.nix via: imports = [ ./xremap.nix ];

{ config, lib, pkgs, ... }:

{
  # --------------------------------------------------------------------------
  # Enable uinput kernel module
  # --------------------------------------------------------------------------
  # xremap needs uinput to intercept and emit keyboard events
  boot.kernelModules = [ "uinput" ];
  
  # --------------------------------------------------------------------------
  # Grant user access to uinput device
  # --------------------------------------------------------------------------
  # Allow non-root users in the 'input' group to access /dev/uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", TAG+="uaccess"
  '';
  
  # --------------------------------------------------------------------------
  # Configure xremap service
  # --------------------------------------------------------------------------
  services.xremap = {
    # Enable the xremap service (required since recent commits default to false)
    enable = true;
    
    # Service mode - run as user service (better for Wayland/per-user sessions)
    # Options: "system" or "user"
    # User mode works better with Hyprland and per-application remapping
    serviceMode = "user";
    
    # userName = "stanley";  # Required if serviceMode = "user"
    
    # Enable Wayland wlroots support (Hyprland is a wlroots compositor)
    # This allows xremap to detect active application windows for per-app remapping
    withWlroots = true;
    
    # --------------------------------------------------------------------------
    # Key remapping configuration
    # --------------------------------------------------------------------------
    # Define your key remaps here using YAML-like syntax
    # See: https://github.com/xremap/xremap#configuration
    config = {
      # Example 1: Swap Caps Lock and Escape (common for vim users)
      modmap = [
        {
          name = "Swap Caps Lock and Escape";
          remap = {
            "CapsLock" = "Esc";
            "Esc" = "CapsLock";
          };
        }
      ];
      
      # Example 2: Per-application remapping
      # Uncomment and customize as needed
      # keymap = [
      #   {
      #     name = "Firefox shortcuts";
      #     application = {
      #       only = [ "firefox" ];  # Only active in Firefox
      #     };
      #     remap = {
      #       "C-n" = "Down";      # Ctrl+N -> Down arrow
      #       "C-p" = "Up";        # Ctrl+P -> Up arrow
      #     };
      #   }
      # ];
    };
  };
}
