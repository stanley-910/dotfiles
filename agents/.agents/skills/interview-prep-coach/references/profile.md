# Profile

This file gives the coach **context for relevance only** — what to cover and what
real material the user can draw on. It is deliberately free of any skill-level
labels, competence ratings, or "already knows / struggles with" claims. Do not
infer the user's ability from anything here. (See the no-priors rule in SKILL.md.)

## Goal

Get into **interviewing shape for new-grad Software Engineer roles**, with
**Databricks** as the primary target. There is **no fixed interview date**:
applications open ~a month out, and the actual interview timeline (including whether
an online assessment gates the live rounds) is unknown. The user has a full-time
job, so the plan runs in two gears — a sustainable **maintenance** cadence by
default, switching to a **sprint** once an interview is actually scheduled (see
`weekly-plan.md`). The aim is a durable capability that keeps compounding, not a
one-time cram. Databricks is a data-infrastructure company, which shapes what the
rounds emphasize (see system-design notes).

## The interview loop (per the user's contact at the company)

Four rounds, in roughly this order:

1. **Algorithm** — standard LeetCode-style, timed, shared editor.
2. **Coding implementation** — open-ended, design-forward: build a real, usable
   primitive (e.g. a small key-value store, a rate limiter, a thread-safe cache)
   with clean, production-quality code. Not about a clever algorithm; about good
   code, interfaces, edge cases, testability.
3. **System design** — at new-grad level, the medium-difficulty, infrastructure-
   flavored prompts (generic KV store, in-memory cache, job scheduler), not the
   staff-level ones.
4. **Behavioral** — STAR format. Databricks weights ownership and impact.

## Background (factual, for behavioral relevance — NOT a capability signal)

- The user's own work is **agentic AI development**: a self-initiated project
  **madden-agent** (FastAPI + LangGraph + OpenAI Responses API + SSE streaming;
  ReAct loops, LangGraph checkpointing) with a companion storefront
  **store-madden** (Remix-based).
- This self-initiated agentic project is strong raw material for behavioral themes
  like "a project you're proud of," "learning something new quickly," and
  "navigating ambiguity."
- Note: any SAP / enterprise-integration material that may appear elsewhere on the
  account is **not** the user's own work (a different person used the account) —
  do not use it for behavioral stories or as background.

## Learning style (preferences, not abilities)

- Prefers Socratic coaching that pushes back, with hints only after real effort.
- Likes building deep, bottom-up understanding (e.g. learning HTTP from TCP upward,
  reading DDIA, understanding networking fundamentals rather than just using them).
- Strong preference for visual/interactive explanation (diagrams, animations) when
  learning a concept — use these when feasible.
- Implementation language for prep is **Python**.

## Supporting study tracks running alongside the LeetCode plan

- **DDIA** (Designing Data-Intensive Applications), ~ch 1–5, plus a light skim of
  the ACID vocabulary in ch 7. Builds the system-design foundation.
- **Boot.dev HTTP trio** (HTTP Protocol, HTTP Servers, HTTP Clients, in Go) to
  close fundamentals gaps in how requests/responses/clients actually work.
- **Networking baseline** — a deliberately narrow slice (see networking.md).
- **Delta Lake transaction log** — one focused read; high Databricks relevance.
- Git deep-dive (Boot.dev Git 1 Internals + Git 2 + Pro Git) runs as a
  **maintenance-gear leisure track** that **pauses in sprint gear** — see `git.md`.
