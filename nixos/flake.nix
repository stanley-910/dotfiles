# ==============================================================================
# NixOS Flake Configuration
# ==============================================================================
# This flake enables reproducible system builds and easy access to external
# packages not in nixpkgs. Your existing configuration.nix and modules remain
# mostly unchanged - this just wraps them in a flake structure.
#
# Usage:
#   sudo nixos-rebuild switch --flake /home/stanley/dotfiles/nixos#nixos
#
# Update dependencies:
#   nix flake update (updates all inputs)
#   nix flake lock --update-input nixpkgs (update specific input)

{
  description = "nixos";

  # --------------------------------------------------------------------------
  # Inputs - External dependencies for your system
  # --------------------------------------------------------------------------
  inputs = {
    # Main nixpkgs repository - use unstable for latest packages
    # You can switch to "nixos-25.11" for stable if preferred
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";
    # Rose Pine Hyprcursor theme 
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs as system
    };
    
    # xremap - Key remapper for Linux supporting X11 and Wayland
    # Allows per-application key remapping with modifier support
    xremap-flake = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs as system
    };
    
    # Noctalia - Custom package
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs as system
    };
  };

  # --------------------------------------------------------------------------
  # Outputs - What this flake produces
  # --------------------------------------------------------------------------
  outputs = { self, nixpkgs, rose-pine-hyprcursor, xremap-flake, noctalia, hyprdynamicmonitors, ... }@inputs:
    let
      # System architecture - change to "aarch64-linux" for ARM systems
      system = "x86_64-linux";
      
      # Import nixpkgs with any overrides or config needed
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;  # Allow unfree packages
      };
    in
    {
      # NixOS system configuration
      # "nixos" is your hostname - change if different
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        
        # Your existing configuration modules
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./power.nix
          ./hyprland.nix
          ./xremap.nix
          ./scripts.nix
          
          # Import xremap NixOS module - provides services.xremap option
          xremap-flake.nixosModules.default
          
          # Import HyprDynamicMonitors NixOS module - provides services.hyprdynamicmonitors option
          hyprdynamicmonitors.nixosModules.default
        ];
        
        # Make flake inputs available to your modules via specialArgs
        # Access in modules with: { config, pkgs, rose-pine-hyprcursor, ... }:
        specialArgs = {
          inherit rose-pine-hyprcursor;
          inherit xremap-flake;
          inherit inputs;
        };
      };
    };
}

