---
description: Open the MR/PR this session is working on
---

Open the merge/pull request for this session's work:

1. Run `agent-link open mr` (bash) with your working tree as cwd — the worktree
   you created for this session, not the main checkout. Use the absolute path
   `~/dotfiles/scripts/bin/agent-link` if it's not on PATH.
2. If it reports nothing recorded and you created or know an MR this session,
   record it first (`agent-link mr <url>`) and rerun.
3. If no MR exists yet, say so plainly — do not create one.
