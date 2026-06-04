#!/bin/bash
# Only mount if not already mounted
if ! mount | grep -q "vault-secrets"; then
    hdiutil attach ~/Documents/vault-secrets.dmg
fi
open -W -a "Obsidian"
hdiutil detach /Volumes/vault-secrets
