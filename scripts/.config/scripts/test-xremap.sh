#!/usr/bin/env bash

# Stop the xremap service
echo "Stopping xremap service..."
systemctl --user stop xremap.service

# Get the current xremap binary and config from the running service
XREMAP_BIN=$(systemctl --user cat xremap.service | grep "ExecStart=" | sed 's/ExecStart=//' | awk '{print $1}')
XREMAP_CONFIG=$(systemctl --user cat xremap.service | grep "ExecStart=" | sed 's/ExecStart=//' | awk '{print $NF}')

# Run xremap with debug logging
echo "Starting xremap with debug logging..."
echo "Binary: $XREMAP_BIN"
echo "Config: $XREMAP_CONFIG"
echo "Press Super key, then Alt key on your Logitech keyboard"
echo "Press Ctrl+C to stop"
echo ""

sudo RUST_LOG=debug $XREMAP_BIN --device 'AT Translated Set 2 keyboard' --device 'Logitech USB Receiver' $XREMAP_CONFIG

# Restart the service when done
echo ""
echo "Restarting xremap service..."
systemctl --user start xremap.service
