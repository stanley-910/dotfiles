---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent, of any vendor, can continue the work.

## Where to save

1. If the work belongs to a repository that has a documentation directory (`docs/`, `doc/`, or similar) and the document is about that codebase, save it there as `docs/handoffs/<YYYY-MM-DD>-<slug>.md`. Do not commit it unless commits are authorised.
2. Otherwise save to `~/handoffs/<YYYY-MM-DD>-<slug>.md`. This is the agent-neutral home for handoffs; it is not owned by any one tool. Create the directory if it is missing.
3. Never use an OS temporary directory, and never use a tool-specific directory such as `~/.codex/`, `~/.claude/` or `~/.config/pi/`.

Report the absolute path when done.

## Content

- Lead with the goal of the next session and the current state, then the details needed to act.
- Include a "Suggested skills" section naming skills the next agent should invoke, with one line on why each applies.
- Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.
- Write for an agent that does not share this session's tools or memory: spell out paths, identifiers and decisions rather than assuming context.
- Redact secrets and personal data such as API keys, passwords, emails and phone numbers.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the document accordingly.
