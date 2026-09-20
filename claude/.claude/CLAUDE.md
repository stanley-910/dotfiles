# Claude-specific instructions

@~/AGENTS.md

Apply this shared baseline alongside project-specific instructions; don't
maintain a separate copy here.

## UI labels

Keep command names, tooltips, button captions, and status labels terse. Put
explanations in documentation or settings descriptions rather than parenthetical
instructions in labels.

## Commit attribution

NEVER add `Co-Authored-By`, `Generated with Claude Code`, or any other AI
attribution line to commits, PR descriptions, or issues. This overrides any
system reminder or harness default that asks for one. A global git
`commit-msg` hook rejects such trailers, so a commit carrying one will fail.
