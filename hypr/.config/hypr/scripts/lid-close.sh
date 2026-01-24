#!/usr/bin/env bash
# Lid close handler - Disable laptop display and move workspaces
# This prevents Hyprland from auto-re-enabling eDP-1 when switching workspaces

# Disable the laptop display
hyprctl keyword monitor "eDP-1,disable"
# Small delay to ensure monitor is disabled
sleep 0.1

# Move all active workspaces to main external monitor (HDMI-A-1)
# This prevents workspace switching from re-enabling the laptop display
for workspace in {1..10}; do
    hyprctl dispatch moveworkspacetomonitor "$workspace HDMI-A-1" 2>/dev/null
done

