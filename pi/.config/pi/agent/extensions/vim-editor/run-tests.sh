#!/usr/bin/env bash
# Runs the vim-editor registration-order regression harness (Node >= 23 for
# native .ts execution). index.ts imports @earendil-works packages by bare
# specifier; Node resolves those by walking up from the importing file, so we
# stage a temp copy of the extension pair with pi's real packages symlinked
# into a sibling node_modules.
set -euo pipefail

ext_dir="$(cd "$(dirname "$0")" && pwd)"
pkg="$(dirname "$(dirname "$(readlink -f "$(command -v pi)")")")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/extensions" "$work/node_modules/@earendil-works"
cp -R "$ext_dir" "$work/extensions/vim-editor"
cp -R "$ext_dir/../inline-slash-completion" "$work/extensions/inline-slash-completion"
ln -s "$pkg" "$work/node_modules/@earendil-works/pi-coding-agent"
ln -s "$pkg/node_modules/@earendil-works/pi-tui" "$work/node_modules/@earendil-works/pi-tui"

status=0; for test in "$work/extensions/vim-editor/"*.test.ts; do node "$test" || status=1; done; exit "$status"
