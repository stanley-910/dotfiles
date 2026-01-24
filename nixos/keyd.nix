# ==============================================================================
# keyd Configuration - Key Remapping for Linux
# ==============================================================================
# keyd is a system-wide key remapper for Linux that works at the kernel level.
# It's simpler than xremap and doesn't require special permissions for each user.
# Import this in configuration.nix via: imports = [ ./keyd.nix ];

{
  config,
  lib,
  pkgs,
  ...
}:

{
  # --------------------------------------------------------------------------
  # Enable keyd service
  # --------------------------------------------------------------------------
  services.keyd = {
    enable = true;

    keyboards = {
      # Default configuration for all keyboards (built-in, etc.)
      default = {
        # Apply to all keyboards by default
        ids = [ "*" ];

        settings = {
          main = {
            # Caps Lock becomes Ctrl
            capslock = "leftcontrol";

            # Right Shift becomes Esc
            rightshift = "esc";
          };
        };
      };

      # Logitech-specific configuration
      # This overrides the default for Logitech keyboards
      logitech = {
        # Target Logitech USB Receiver specifically
        # To find device IDs, run: keyd list-devices
        # Format is usually vendor:product (e.g., "046d:*" for all Logitech devices)
        ids = [ "046d:*" ]; # Logitech vendor ID

        settings = {
          main = {
            # Swap Super (Meta) and Alt keys on Logitech keyboards
            leftmeta = "leftalt";
            leftalt = "leftmeta";

            # Left Shift becomes Esc on Logitech keyboards
            leftshift = "esc";

            # Also apply the default mappings
            capslock = "leftcontrol";
            rightshift = "esc";
          };
        };
      };
    };
  };

  # --------------------------------------------------------------------------
  # Optional: Palm rejection for keyd virtual keyboard
  # --------------------------------------------------------------------------
  # Makes the keyd virtual keyboard behave like an internal keyboard
  # This helps with palm rejection on touchpads
  # Reference: https://github.com/rvaiya/keyd/issues/723
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Serial Keyboards]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  # --------------------------------------------------------------------------
  # Install keyd package for CLI tools
  # --------------------------------------------------------------------------
  # Provides keyd command-line tools like 'keyd list-devices'
  # Note: The service installation happens via services.keyd.enable
  environment.systemPackages = with pkgs; [
    keyd
  ];
}
