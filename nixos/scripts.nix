# ==============================================================================
# Custom Scripts Module
# ==============================================================================
# Makes custom scripts globally accessible as system packages.
# Import this in configuration.nix via: imports = [ ./scripts.nix ];

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # nixswitch - Wrapper for nixos-rebuild with git integration
    # Reads from ../scripts/.config/scripts/nix-rebuild
    # is this any better / worse than just symlinking the scripts to /usr/local/bin?
    (writeShellScriptBin "nixswitch" (builtins.readFile ../scripts/.config/scripts/nix-rebuild))
    (writeShellScriptBin "organize-class-files" (builtins.readFile ../scripts/.config/scripts/organize-class-files))
    
    # Add more custom scripts here as needed
    # Example:
    # (writeShellScriptBin "my-script" (builtins.readFile ../scripts/.config/scripts/my-script))
  ];
}
