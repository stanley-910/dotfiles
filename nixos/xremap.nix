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
  # Allow non-root users in the 'input' group to access /dev/uinput
  hardware.uinput.enable = true;
  users.groups.uinput.members = [ "stanley" ];
  users.groups.input.members = [ "stanley" ]; # this may allow xremap to start on boot? 


  
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
    
    # Specify which user to run the service as (required for user mode)
    userName = "stanley";
    
    # Enable Wayland wlroots support (Hyprland is a wlroots compositor)
    # This allows xremap to detect active application windows for per-app remapping
    withWlroots = true;
    
    # Target specific devices by name - fixes reconnect detection issues
    # These are grabbed explicitly instead of auto-detection
    deviceNames = [
      "AT Translated Set 2 keyboard"  # Built-in laptop keyboard
      "Logitech USB Receiver"          # External keyboard via dock
    ];
    
    # --------------------------------------------------------------------------
    # Key remapping configuration
    # --------------------------------------------------------------------------
    # Define your key remaps here using YAML-like syntax
    # See: https://github.com/xremap/xremap#configuration
    config = {
      # Dual-function Caps Lock: Alt when held, Escape when tapped
      # This is incredibly useful - you get Escape in a easy-to-reach position
      # while still having a left-side Alt for shortcuts
      modmap = [
        {
          name = "Caps Lock as Alt/Escape (dual function)";
          remap = {
            "CapsLock" = "Ctrl_L";
            "Shift_R" = "Esc";
          };
        }
        # Device-specific: Swap Alt and Meta keys for Logitech keyboard only
        # Using event14 which corresponds to the Logitech USB Receiver keyboard
      ];
      keymap = [
        {
          name = "Enter app launcher mode";
          remap = {  
            # Super+D enters the "app_launcher" mode
            "Super-d" = {
              set_mode = "app_launcher";
            };
          };
        }
        {
          name = "App launcher mode bindings";
          remap = {
            # Launch firefox and auto-exit mode
            # Array syntax = sequence of actions (like the Emacs example)
            "f" = [
              { launch = ["firefox"]; }
              # { set_mode = "default"; }
            ];
            # Launch Cursor editor and auto-exit mode
            "c" = [
              { launch = ["cursor"]; }
              # { set_mode = "default"; }
            ];
            "g" = [
              { launch = ["ghostty"]; }
              # { set_mode = "default"; }
            ];
            # Manual exit if needed
            "Esc" = {
              set_mode = "default";
            };
          };
          mode = "app_launcher";  # This keymap is only active in this mode
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

  # --------------------------------------------------------------------------
  # Extend xremap service environment
  # --------------------------------------------------------------------------
  # Set PATH to include system and user packages from NixOS
  # This gives xremap access to all installed packages without listing them
  # twice (cleaner and more maintainable than manual path management)
  # 
  # lib.mkForce overrides the default PATH that xremap module sets
  # (which only includes basic coreutils, grep, sed, etc.)
  systemd.user.services.xremap = {
    environment = {
      # /run/current-system/sw/bin = system packages (environment.systemPackages)
      # /etc/profiles/per-user/<user>/bin = user-specific packages
      PATH = lib.mkForce "/run/current-system/sw/bin:/etc/profiles/per-user/${config.services.xremap.userName}/bin:/home/${config.services.xremap.userName}/.nix-profile/bin";
    };
  };

  # --------------------------------------------------------------------------
  # Restart xremap after suspend/resume
  # --------------------------------------------------------------------------
  # When the system wakes from suspend, input devices get re-initialized by the kernel.
  # xremap loses connection to these devices (causing "No such device" errors).
  # We verified that manually restarting xremap fixes this, so we automate it here.
  # 
  # This system service runs after waking from sleep and restarts the user's xremap service.
  systemd.services.xremap-resume = {
    description = "Restart xremap after suspend/resume";
    # Trigger after the system wakes from sleep
    wantedBy = [ "sleep.target" ];
    after = [ "sleep.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      # Restart the user's xremap service
      # -M targets a specific user's systemd instance
      ExecStart = "${pkgs.systemd}/bin/systemctl --user -M ${config.services.xremap.userName}@ restart xremap.service";
    };
  };

  # --------------------------------------------------------------------------
  # Restart xremap when USB input devices reconnect (e.g., dock replug)
  # --------------------------------------------------------------------------
  # --watch doesn't reliably catch all device reconnects, so we use udev as backup.
  # The delay allows the device to fully initialize before xremap grabs it.
  services.udev.extraRules = ''
    # Restart xremap when USB keyboards are added
    ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="${pkgs.systemd}/bin/systemctl --no-block start xremap-usb-restart.service"
  '';

  # Service triggered by udev to restart xremap after USB keyboard reconnect
  # systemd.services.xremap-usb-restart = {
  #   description = "Restart xremap after USB keyboard reconnect";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     # Delay to let device initialize
  #     ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
  #     ExecStart = "${pkgs.systemd}/bin/systemctl --user -M ${config.services.xremap.userName}@ restart xremap.service";
  #   };
  # };
}
