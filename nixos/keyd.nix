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
      # Laptop keyboard configuration
      # Device ID: 0001:0001 (AT Translated Set 2 keyboard)
      laptop = {
        ids = [ "0001:0001" ];

        settings = {
          main = {
            capslock = "leftcontrol";
            rightshift = "esc";
          };
        };
      };

      # Logitech keyboard configuration
      # Device ID: 046d:c548 (Logitech USB Receiver)
      # Named with 'z' prefix so it's processed after 'laptop' alphabetically
      zlogitech = {
        ids = [ "046d:c548" ];

        settings = {
          main = {
            # Global mappings
            capslock = "leftcontrol";
            rightshift = "esc";

            # Logitech-specific: Swap Super/Alt keys
            leftmeta = "leftalt";
            leftalt = "leftmeta";

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
