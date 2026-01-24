# ==============================================================================
# xremap Configuration - Key Remapping for Wayland/X11
# ==============================================================================
# xremap allows remapping keys globally or per-application.
# Great for customizing keyboard layouts, creating custom shortcuts, etc.
# Import this in configuration.nix via: imports = [ ./xremap.nix ];

{
  config,
  lib,
  pkgs,
  ...
}:

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
      "AT Translated Set 2 keyboard" # Built-in laptop keyboard
      "Logitech USB Receiver" # External keyboard via dock
    ];

    # Use yamlConfig for raw YAML to avoid Nix conversion issues
    yamlConfig = ''
      modmap:
        - name: "Caps Lock as Ctrl, Right Shift as Esc"
          remap:
            CapsLock: Ctrl_L
            Shift_R: Esc
        
        - name: "Swap Super and Alt on Logitech keyboard"
          device:
            only: "Logitech USB Receiver"
          remap:
            Shift_L: Esc
      
      keymap:
        - name: "Enter app launcher mode"
          remap:
            Super-d:
              set_mode: app_launcher
        
        - name: "App launcher mode bindings"
          mode: app_launcher
          remap:
            f:
              - launch: ["firefox"]
            c:
              - launch: ["cursor"]
            g:
              - launch: ["ghostty"]
            Esc:
              set_mode: default
    '';
  };
  # Old config attribute set removed - using yamlConfig instead

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
      # Enable debug logging to see key events
      RUST_LOG = "debug";
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
