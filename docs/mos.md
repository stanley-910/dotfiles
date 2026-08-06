# Mos settings snapshot

Mos (smooth scrolling for non-Apple mice) is installed as a cask and seeded by
`prepper.sh` (`step_mos`). Mos rewrites its own plist on quit — floats gain
precision and keybindings serialize to binary — so `dotfiles-drift` audits will
always flag its values as mismatched. That is expected; this file is the
human-readable source of truth.

Settings as of 2026-08-05 (from the Mos preferences UI):

| Setting          | Value                                    |
| ---------------- | ---------------------------------------- |
| Smooth Scrolling | on (seamless)                            |
| Scroll Reverse   | off                                      |
| Dash Key         | disabled                                 |
| Toggle Key       | Shift (vertical → horizontal scrolling)  |
| Block Key        | Control (temporarily block smoothing)    |
| Step             | 30.70                                    |
| Speed            | 3.50                                     |
| Duration         | 1.41                                     |

To reproduce on a fresh Mac: run `prepper.sh` (seeds these via `defaults
write`), or set them by hand in Mos preferences. The Toggle/Block bindings in
`prepper.sh` are Mos's own serialized hex for Shift/Control — regenerate them
from the UI if you change keys.
