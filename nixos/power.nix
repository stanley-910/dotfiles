# ==============================================================================
# Power Management Configuration
# ==============================================================================
# This module handles power management, battery optimization, and related settings.
# Import this in configuration.nix via: imports = [ ./power.nix ];

{ config, lib, pkgs, ... }:

{
  powerManagement.enable = true;
  
  # --------------------------------------------------------------------------
  # TLP - Advanced Power Management for Linux
  # --------------------------------------------------------------------------
  # TLP is a feature-rich command-line utility for Linux, saving laptop battery 
  # power without the need to understand every technical detail.
  services.tlp = {
    enable = true;
    settings = {
      # CPU Governor: "powersave" for battery, "performance" for AC
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # CPU Energy/Performance Policy (Intel HWP)
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Processor boost (turbo) mode
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Runtime Power Management for PCI(e) devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;

      # Battery charge thresholds (if supported by hardware)
      # Helps prolong battery lifespan by not charging to 100%
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 90;
    };
  };

  # --------------------------------------------------------------------------
  # Thermald - Thermal Management
  # --------------------------------------------------------------------------
  # Prevents overheating on Intel CPUs
  services.thermald.enable = true;

  # --------------------------------------------------------------------------
  # UPower - Power Device Daemon
  # --------------------------------------------------------------------------
  # Provides power/battery information to desktop environments
  services.upower = {
    enable = true;
    # Percentage at which to consider battery critical
    percentageCritical = 5;
    # Percentage at which to consider battery low
    percentageLow = 15;
    # Action when battery reaches critical level: Hibernate, PowerOff, or HybridSleep
    criticalPowerAction = "Hibernate";
  };

  # TODO: add logind configuration for handling power button and lid actions

  # --------------------------------------------------------------------------
  # Power-related packages
  # --------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    powertop       # Power consumption analyzer
  ];
}

