#!/bin/bash
# Redirect Claude Code worktrees to ~/.config/worktrees/<project>/ (outside iCloud)
set -euo pipefail

WORKTREE_BASE="$HOME/.config/worktrees"

# Read stdin JSON (Claude Code passes hook context here, ignore it)
INPUT=$(cat)

# Derive project name from the repo root directory name
PROJECT=$(basename "$(git rev-parse --show-toplevel)")

# Generate a unique branch name
BRANCH_NAME="claude-$(date +%s)"

TARGET="$WORKTREE_BASE/$PROJECT/$BRANCH_NAME"
mkdir -p "$(dirname "$TARGET")"

git worktree add -b "$BRANCH_NAME" "$TARGET"
echo "$TARGET"
