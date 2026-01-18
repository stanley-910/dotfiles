# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      
      # Custom modules
      ./power.nix           # Power management and battery optimization
      ./hyprland.nix        # Hyprland window manager and desktop components
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system (for XWayland compatibility)
  services.xserver = {
    enable = true;
    # Using Hyprland (Wayland) instead of X11 window managers
    # windowManager.qtile.enable = false;
  };


  

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.stanley = {
    isNormalUser = true;
    # Enable 'sudo' and grant permissions for input devices and graphics
    extraGroups = [ 
      "wheel"   # Enable sudo for the user
      "input"   # Required for Hyprland to access input devices (/dev/input/*)
      "video"   # Required for GPU access and graphics operations
      "seat"    # Required for seat management (seatd)
    ];
    shell = pkgs.zsh;          # Set zsh as default shell
    packages = with pkgs; [
      tree
    ];
  };

  # Register zsh in /etc/shells (required for GDM and login managers)
  environment.shells = with pkgs; [ zsh ];

  # Enable and configure zsh system-wide (NixOS-native plugin management)
  programs.zsh = {
    enable = true;
    enableCompletion = true;           # Enables vendor completions from Nixpkgs
    autosuggestions.enable = true;     # zsh-autosuggestions (no manual clone needed)
    syntaxHighlighting.enable = true;  # zsh-syntax-highlighting (no manual clone needed)
  };

  programs.firefox.enable = true;

  # List packages installed in system profile. -- Package manager
  # You can use https://search.nixos.org/ to find more packages (and options).

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # Core editors and tools
    vim       # Do not forget to add an editor to edit configuration.nix!
    neovim    # Modern vim-based editor
    wget
    git
    
    # Terminal and shell tools
    ghostty   # GPU-accelerated terminal
    tmux      # Terminal multiplexer
    starship  # Cross-shell prompt
    
    # Modern CLI replacements
    eza       # Modern ls with git integration
    bat       # Modern cat with syntax highlighting
    fd        # Modern find
    ripgrep   # Fast grep alternative
    fzf       # Fuzzy finder
    zoxide    # Smart cd replacement
    
    # Utilities
    stow      # Symlink manager for dotfiles
    fastfetch # System info display
    yazi      # Terminal file manager
    tree      # Directory tree viewer
    jq        # JSON processor
    ffmpeg    # Media processing
    xclip     # Clipboard tool (replaces pbcopy on macOS)
    
    # GUI applications
    btop        # System monitor
    code-cursor # AI-powered code editor
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

