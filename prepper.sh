#!/usr/bin/env bash
# ============================================================================
# Fresh macOS Bootstrap — Stage 1
# ============================================================================
# Run this FIRST on a brand-new Mac, before cloning the dotfiles repo:
#
#   curl -fsSL <gist-raw-url> | bash
#
# What it does (in order):
#   1. Installs Homebrew
#   2. Installs Claude Code (auth happens later, after dotfiles are stowed)
#   3. Installs every GUI app cask
#   4. Sets Helium as the default browser
#   5. Applies macOS system defaults (Finder, Dock, Keyboard, Trackpad, ...)
#   6. Configures Mos (smooth-scroll daemon)
#   7. Generates a GitHub SSH key and walks through registering it
#   8. Clones the dotfiles repo
#
# When this finishes, run Stage 2:
#   cd ~/dotfiles && ./bootstrap.sh
# Stage 2 installs CLI dev tools (Brewfile), zsh plugins, and stows configs.
#
# ----------------------------------------------------------------------------
# Recovery model
# ----------------------------------------------------------------------------
# Every step is idempotent — re-running the script is safe and cheap:
#   * brew skips already-installed formulae/casks
#   * `defaults write` just overwrites the same key with the same value
#   * SSH key / dotfiles clone check for existing artifacts before acting
# If any step fails, the script keeps going and prints a summary at the end
# listing which steps failed. Fix the underlying issue, re-run the script,
# and only the failed steps will do real work the second time.
# ============================================================================

set -uo pipefail   # NOTE: deliberately no `-e` — we want every step to run.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLU}[INFO]${NC}  $1"; }
success() { echo -e "${GRN}[OK]${NC}    $1"; }
warn()    { echo -e "${YLW}[WARN]${NC}  $1"; }
err()     { echo -e "${RED}[ERR]${NC}   $1"; }

# When this script is piped from curl, stdin is the pipe — not the terminal.
# All interactive reads must come from /dev/tty explicitly.
ask()   { read -r -p "$2" "$1" </dev/tty; }
pause() { read -r -p "$(echo -e "${YLW}[PAUSE]${NC} $1 Press Enter to continue... ")" _ </dev/tty; }

# Step-runner: invokes a named step, records failure, never aborts the script.
# Usage: run_step "Human-readable name" function_name
FAILED_STEPS=()
run_step() {
    local name="$1" fn="$2"
    echo ""
    info "▶ $name"
    if "$fn"; then
        success "✓ $name"
    else
        err   "✗ $name (will be reported in summary; safe to re-run script)"
        FAILED_STEPS+=("$name")
    fi
}

# Prime sudo up front so later sudo'd commands don't stall mid-run.
info "This script needs sudo for a few commands (hostname, DNS flush)."
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# ---------------------------------------------------------------------------
# Step 1: Homebrew
# ---------------------------------------------------------------------------
step_homebrew() {
    # Probe known install locations FIRST — on re-runs, brew may exist on disk
    # but not be in PATH (curl|bash spawns a non-login shell that doesn't read
    # ~/.zprofile, where the installer puts its shellenv line). If we find it,
    # just eval shellenv and skip straight to verifying.
    if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
    elif ! command -v brew >/dev/null 2>&1; then
        # Genuinely not installed — run the official installer, then re-source.
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
        if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    # Note: we don't touch ~/.zprofile here — dotfiles owns that file and
    # Stage 2 will stow it cleanly. The brew installer DOES write its own
    # shellenv line to ~/.zprofile on a fresh install, which Stage 2's
    # backup logic will move aside.
    command -v brew >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Step 2: Claude Code
# ---------------------------------------------------------------------------
# Installed now so it's available later. We DON'T log in here because auth
# needs to happen after dotfiles are stowed (so settings.json lands first).
step_claude_code() {
    if command -v claude >/dev/null 2>&1; then
        info "Claude Code already present"
        return 0
    fi
    curl -fsSL https://claude.ai/install.sh | bash
}

# ---------------------------------------------------------------------------
# Step 3: GUI app casks
# ---------------------------------------------------------------------------
# Every GUI app lives here so there's one source of truth for "what apps am
# I installing?". CLI dev tools (stow, git, eza, ripgrep, ...) are in the
# dotfiles Brewfile and get installed by Stage 2.
step_casks() {
    local casks=(
        ghostty             # terminal emulator
        karabiner-elements  # keyboard remapper (caps→esc, etc.)
        zed                 # editor
        cursor              # AI editor
        obsidian            # notes
        raycast             # Spotlight replacement / launcher
        logi-options+       # Logitech mouse & keyboard config
        mos                 # smooth scrolling for non-Apple mice
        alt-tab             # Windows-style window switcher
        betterdisplay       # external monitor tuning
        helium-browser      # browser (set as default in the next step; NOT the deprecated `helium` cask, which is an unrelated Android-mirroring app)
        sioyek              # PDF viewer — cask is disabled upstream, expect a warning
    )
    local failed=()
    for cask in "${casks[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            info "  $cask already installed"
        else
            info "  Installing $cask..."
            brew install --cask "$cask" || failed+=("$cask")
        fi
    done
    if (( ${#failed[@]} > 0 )); then
        warn "Failed casks: ${failed[*]} (re-run script to retry)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Step 4: Default browser → Helium
# ---------------------------------------------------------------------------
# `defaultbrowser` is a tiny CLI that flips the LaunchServices default
# without forcing us into System Settings. macOS still shows ONE confirmation
# prompt the first time — that's expected, click "Use Helium".
step_default_browser() {
    if ! command -v defaultbrowser >/dev/null 2>&1; then
        brew install defaultbrowser >/dev/null || return 1
    fi
    if defaultbrowser 2>/dev/null | grep -qi helium; then
        defaultbrowser helium
        info "  Confirm the system prompt if shown"
    else
        warn "Helium not in defaultbrowser's list — set manually in System Settings"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Step 5: macOS system defaults
# ---------------------------------------------------------------------------
# Re-applying the same defaults is a no-op, so this step is fully re-runnable.
step_macos_defaults() {

    # --- Keyboard ----------------------------------------------------------
    # Fast key repeat is the single most important setting for vim-style editing.
    # (2/30 matches the lived-in setting from the 2026 machine; 1/10 proved
    # faster than actually wanted.)
    defaults write NSGlobalDomain KeyRepeat                              -int 2
    defaults write NSGlobalDomain InitialKeyRepeat                       -int 30
    # Disable the press-and-hold accent menu so j/k/l/etc. repeat as expected.
    defaults write -g ApplePressAndHoldEnabled                           -bool false
    # Kill every auto-substitution — they all corrupt code.
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled   -bool false
    defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled       -bool false
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled    -bool false
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled     -bool false
    defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled   -bool false
    # Tab through every UI control, not just text inputs.
    defaults write NSGlobalDomain AppleKeyboardUIMode                    -int 3
    # Helium app shortcuts: Option+Q/D for browser back/forward.
    defaults write net.imput.helium NSUserKeyEquivalents -dict-add \
        "Back" "~q" \
        "Forward" "~d"

    # --- Trackpad ----------------------------------------------------------
    # Tap-to-click on both the built-in trackpad and any Bluetooth ones.
    defaults write com.apple.AppleMultitouchTrackpad                  Clicking -bool true
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    # Tracking speed: 0 (slow) → 3 (fast).
    defaults write NSGlobalDomain com.apple.trackpad.scaling          -float 2.5
    # Natural scrolling — content follows fingers.
    defaults write NSGlobalDomain com.apple.swipescrolldirection      -bool true
    # Three-finger drag = grab windows without click-and-hold.
    defaults write com.apple.AppleMultitouchTrackpad                  TrackpadThreeFingerDrag -bool true
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
    # Mission Control / App Exposé / space-switching gestures: with 3-finger
    # drag enabled, push these to 4 fingers so they don't collide.
    #   Value 1 = 4 fingers, Value 2 = 3 fingers.
    defaults write com.apple.AppleMultitouchTrackpad                  TrackpadThreeFingerVertSwipeGesture  -int 1
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture  -int 1
    defaults write com.apple.AppleMultitouchTrackpad                  TrackpadThreeFingerHorizSwipeGesture -int 1
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 1
    # The on/off toggle for these gestures lives in Dock prefs.
    defaults write com.apple.dock showMissionControlGestureEnabled    -bool true
    defaults write com.apple.dock showAppExposeGestureEnabled         -bool true

    # --- Finder ------------------------------------------------------------
    defaults write com.apple.finder AppleShowAllFiles    -bool true       # show dotfiles
    defaults write com.apple.finder ShowPathbar          -bool true
    defaults write com.apple.finder ShowStatusBar        -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "clmv"   # column view
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search current folder, not whole Mac
    chflags nohidden ~/Library                                            # unhide ~/Library
    # Don't litter network shares or USB drives with .DS_Store.
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores     -bool true

    # --- Dock & Mission Control --------------------------------------------
    defaults write com.apple.dock expose-animation-duration -float 0.1
    # Clean slate: wipe Apple's default-pinned dock apps. Re-pin manually later.
    defaults delete com.apple.dock persistent-apps 2>/dev/null || true

    # --- Menu bar ----------------------------------------------------------
    defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true

    # --- Screenshots -------------------------------------------------------
    # Send screenshots to the clipboard instead of cluttering the Desktop.
    defaults write com.apple.screencapture target -string "clipboard"

    # --- Spotlight / Services hotkey cleanup -------------------------------
    # Disable the Spotlight hotkeys so Raycast can claim Cmd+Space.
    #   64 = "Show Spotlight search"    (Cmd+Space)
    #   65 = "Show Finder search window" (Cmd+Opt+Space)
    # We go through `defaults write` (not PlistBuddy) because cfprefsd caches
    # this plist in memory — a direct file edit gets silently overwritten
    # when cfprefsd flushes its cache. `defaults write` routes through
    # cfprefsd, keeping the daemon in sync.
    # The full dict (with `value` → keycode/modifiers) must be preserved or
    # macOS treats the entry as malformed, so we use `-dict-add` with the
    # original parameters for each hotkey (keycode 49 = Space).
    for hk_id in 64 65; do
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
            -dict-add "$hk_id" "
            <dict>
                <key>enabled</key><false/>
                <key>value</key><dict>
                    <key>type</key><string>standard</string>
                    <key>parameters</key>
                    <array>
                        <integer>32</integer>
                        <integer>49</integer>
                        <integer>$([ "$hk_id" = 64 ] && echo 1048576 || echo 1572864)</integer>
                    </array>
                </dict>
            </dict>"
    done
    # cfprefsd must re-read symbolichotkeys for the change to apply; a
    # logout/login is the only reliable way to make WindowServer pick it up.
    killall cfprefsd 2>/dev/null || true
    # Disable the Stickies "Make New Sticky Note" Service binding — it eats
    # common editor shortcuts via the Services menu.
    defaults write pbs NSServicesStatus -dict-add \
        "com.apple.Stickies - Make New Sticky Note - makeStickyNote" \
        '{enabled_context_menu = 0; enabled_services_menu = 0;}'

    # --- Hostname & DNS ----------------------------------------------------
    sudo scutil --set HostName      "stans-mbp"
    sudo scutil --set LocalHostName "stans-mbp"
    sudo scutil --set ComputerName  "Stan's MBP"
    # Flush DNS so any stale records from the initial setup go away.
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder

    # --- Misc quality of life ----------------------------------------------
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool  true    # expand Save panels
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint    -bool  true    # expand Print panels
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud  -bool  false   # save to disk, not iCloud
    defaults write com.apple.LaunchServices LSQuarantine             -bool  false   # no "are you sure?" on downloads
    defaults write NSGlobalDomain NSWindowResizeTime                 -float 0.001   # snappy window resize
    defaults write com.apple.CrashReporter DialogType                -string "none"
}

# ---------------------------------------------------------------------------
# Step 6: Mos configuration
# ---------------------------------------------------------------------------
step_mos() {
    # Mos overwrites its plist on quit, so it MUST be quit before we write.
    killall Mos 2>/dev/null || true
    sleep 1
    # These are seed values only: Mos normalizes them on quit (floats gain
    # precision, keybindings become binary plist data), so drift audits will
    # always report mismatches here — that's expected, not drift. Current
    # settings are documented in docs/mos.md.
    defaults write com.caldis.Mos smooth         -bool true
    defaults write com.caldis.Mos reverse        -bool false
    defaults write com.caldis.Mos step           -float 30.70319154281626
    defaults write com.caldis.Mos speed          -float 3.5
    defaults write com.caldis.Mos duration       -float 1.414965986394558
    defaults write com.caldis.Mos hideStatusItem -bool true
    # Mos stores its modifier-key bindings as a packed binary blob. The hex
    # below decodes to:
    #   toggle → {"cod":56,"type":"keyboard"}  → Left Shift  (toggles smoothing)
    #   block  → {"cod":59,"type":"keyboard"}  → Left Ctrl   (passes raw scroll while held)
    # Generated by Mos's own UI; this is just the serialized form it writes.
    defaults write com.caldis.Mos toggle -data 7b22636f64223a35362c2274797065223a226b6579626f617264227d
    defaults write com.caldis.Mos block  -data 7b22636f64223a35392c2274797065223a226b6579626f617264227d
    # Add Mos as a Login Item — only if it isn't already there, so re-running
    # the script doesn't pile up duplicates.
    osascript <<'OSA' 2>/dev/null || true
tell application "System Events"
    if not (exists login item "Mos") then
        make login item at end with properties {path:"/Applications/Mos.app", hidden:false}
    end if
end tell
OSA
    open -a Mos 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Step 7: Reload preference daemons
# ---------------------------------------------------------------------------
# Apply all the `defaults write` calls above without a logout.
step_reload_daemons() {
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
    killall Finder         2>/dev/null || true
    killall Dock           2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
    killall pbs            2>/dev/null || true
    return 0
}

# ---------------------------------------------------------------------------
# Step 8: GitHub SSH key
# ---------------------------------------------------------------------------
step_ssh_key() {
    local ssh_key="$HOME/.ssh/id_ed25519"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$ssh_key" ]]; then
        info "SSH key already exists at $ssh_key"
    else
        local gh_email
        ask gh_email "GitHub email (used as the SSH key comment): "
        ssh-keygen -t ed25519 -C "$gh_email" -f "$ssh_key" -N "" || return 1
        # Tell ssh to load this key from the macOS Keychain so it survives reboots.
        if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
            cat >> "$HOME/.ssh/config" <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
        fi
        eval "$(ssh-agent -s)" >/dev/null
        ssh-add --apple-use-keychain "$ssh_key"
    fi

    pbcopy < "${ssh_key}.pub"
    success "Public key copied to clipboard"
    open "https://github.com/settings/ssh/new"

    # Retry loop: keep prompting until GitHub actually accepts the key. This
    # prevents step 9 (clone) from running with broken auth.
    # `ssh -T git@github.com` always exits 1 (no shell allocated), so we
    # grep the output for the success message instead of using $?.
    local attempt=1
    while true; do
        pause "Paste the key into GitHub and save it. (attempt $attempt)"
        info "Testing SSH connection to GitHub..."
        local out
        out=$(ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
        echo "$out"
        if grep -q "successfully authenticated" <<<"$out"; then
            return 0
        fi
        warn "GitHub didn't accept the key yet."
        local retry
        ask retry "Retry? [Y/n] "
        [[ "$retry" =~ ^[Nn] ]] && return 1
        attempt=$((attempt + 1))
    done
}

# ---------------------------------------------------------------------------
# Step 9: Clone dotfiles
# ---------------------------------------------------------------------------
step_clone_dotfiles() {
    local dotfiles_dir="$HOME/dotfiles"
    if [[ -d "$dotfiles_dir/.git" ]]; then
        info "Dotfiles already cloned at $dotfiles_dir"
        return 0
    fi
    git clone git@github.com:stanley-910/dotfiles.git "$dotfiles_dir"
}

# ---------------------------------------------------------------------------
# Run all steps
# ---------------------------------------------------------------------------
run_step "Install Homebrew"               step_homebrew
run_step "Install Claude Code"            step_claude_code
run_step "Install GUI app casks"          step_casks
run_step "Set Helium as default browser"  step_default_browser
run_step "Apply macOS system defaults"    step_macos_defaults
run_step "Configure Mos"                  step_mos
run_step "Reload preference daemons"      step_reload_daemons
run_step "Set up GitHub SSH key"          step_ssh_key
run_step "Clone dotfiles repo"            step_clone_dotfiles

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================================================"
if (( ${#FAILED_STEPS[@]} == 0 )); then
    success "Stage 1 complete — every step succeeded."
else
    warn "Stage 1 finished with ${#FAILED_STEPS[@]} failed step(s):"
    for s in "${FAILED_STEPS[@]}"; do
        echo "    ✗ $s"
    done
    echo ""
    warn "Fix the underlying issue and re-run this script — completed steps"
    warn "will short-circuit, only the failed ones will retry."
fi
echo "======================================================================"
echo ""
info "Next: run Stage 2 (Brewfile dev tools + stow):"
echo "    cd ~/dotfiles && ./bootstrap.sh"
echo ""
info "After that, authenticate Claude Code:"
echo "    claude"
echo ""
