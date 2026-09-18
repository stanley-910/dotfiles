# Pi-specific instructions

Shared communication preferences and personal boundaries live in `~/AGENTS.md`,
which Pi discovers for workspaces under the home directory. For work elsewhere,
read that file as well.

Pi's selected provider and model come from its settings or the current session;
don't infer them from another harness's configuration.

For persistent isolated work, create explicit worktrees and pass their absolute
paths to workers. The installed pi-subagents plugin's built-in worktree isolation
auto-commits changes; don't use that mode unless those commits are authorized.
