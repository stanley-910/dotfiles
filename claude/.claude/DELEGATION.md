# Delegation — Pi/Copilot fleet

Fable-5 driver offloads token-heavy or parallelizable work to the flat-rate
enterprise Copilot fleet through the Pi harness. This file holds the mechanics;
the trigger/policy lives in `CLAUDE.md`.

## Three patterns

**A. Direct shell-out.** Driver runs `pi -p` itself. The pi transcript lands in
the driver's context — cheap for one short worker, costly for many or verbose
ones.

    pi -p --provider github-copilot --model claude-opus-4.8:high \
       --tools read,grep,find,ls --no-session "<handoff>"

**B. Native Claude subagent.** Ordinary Agent-tool workflow on a Claude model,
no Pi. Use when the work genuinely needs Claude (shared session reasoning, Claude
tools, judgment the driver must see in full).

**C. Claude-wrapped Pi worker (token-saving).** When you want the Agent tool's
parallel/background orchestration and UI row, but the reasoning cost on the
flat-rate fleet: launch a cheap `sonnet` launcher subagent that does no work
itself — it `exec`s pi, waits, and relays only the compact report. Heavy tokens
burn on Copilot; the driver sees four lines.

    Agent(
      subagent_type="general-purpose",
      model="sonnet",                    # launcher tier; does NOT reason about the task
      description="Impl A2 →pi opus4.8",  # →pi marks a Copilot-wrapped run, not native sonnet
      run_in_background=true,
      prompt="<wrapper prompt, below>"
    )

Wrapper prompt:

    RUN_LEDGER role=launcher wraps=impl slice=a2 requested_model=github-copilot/claude-opus-4.8:high worktree=<abs>
    You are a thin launcher. Do NOT do the task yourself. Do NOT reason about it.
    Run exactly this, wait for it to finish, return its output:
      cd <worktree> && pi -p --provider github-copilot --model claude-opus-4.8:high \
        --approve "<inner handoff — the real task, in the handoff template below>"
    Return the worker report verbatim; if >60 lines, return only its
    STATUS/CHANGED/VERIFY/BLOCKERS block. If pi errors or is unavailable, return:
    STATUS: BLOCKED — <error line>. Do not edit files yourself.

Parallel fan-out: launch several pattern-A `pi -p` (Bash `run_in_background`) or
several pattern-C wrappers in one turn.

## Launch flags

- Read-only scout: `--tools read,grep,find,ls`
- Implementer in a worktree: pass abs path, add `--approve` to trust project files
- One-shot, no saved session: `--no-session`
- Second opinion / bigger slice: swap model to `gpt-5.5:xhigh`

## Route by context ceiling (working set must fit the worker)

    claude-opus-4.8     200K — deepest reasoning; slices ≤~150K (64K output headroom)
    gpt-5.5             400K — larger loads, breadth, second opinion
    claude-sonnet-4.6     1M — huge-context scouting/reads
    gpt-5.4-mini/5-mini      — cheap mechanical fan-out
    gpt-5.3-codex            — code-only slices, no cross-contract risk

Size slices ≤200K so any worker can take them. Split before exceeding; only an
unsplittable >200K slice routes to gpt-5.5 (≤400K) or sonnet-4.6 (≤1M).

## Header — first line of every detached subagent's prompt

Applies broadly, not just Pi-wrapped delegation: any Agent-tool background
launch, Workflow `agent()` call, or Pi shell-out gets this header.

    RUN_LEDGER role=<scout|impl|verify|merge|launcher> slice=<id|none> model=<id>:<thinking|effort|inherited> worktree=<abs|none>

`model=` is the actual model+thinking/effort the subagent runs at, not just
what was requested. Default behavior for native Claude subagents is to
inherit the parent thread's model and reasoning effort — write
`model=inherited(<resolved value>)` rather than omitting it. For Pi/Copilot
workers, `<thinking>` is the model's thinking-level suffix (e.g. `opus4.8:high`).
For Workflow `agent()` calls, `<effort>` is the `opts.effort` value if set,
else `inherited`.

UI/Agent label tags the real executor: `Impl A2 →pi opus4.8`, `Scout PRD →pi
gpt5.5`, `Verify A2 opus4.8`, `Impl A2 sonnet4.6:inherited`. Tags: opus4.8,
gpt5.5, gpt5.4m, sonnet4.6, haiku4.5. A Copilot-wrapped run must be marked
(`→pi`) — never labeled as if the wrapper's Claude model did the work. Every
label states model + thinking/effort, even when both are inherited — a bare
role name (`Impl A2`) with no model tag is not acceptable.

## Handoff — simple, clear, self-contained

    RUN_LEDGER ...
    Goal: <one line>
    Scope: <abs paths / files only — keep read-set under the worker's ceiling>
    Do: <acceptance criteria + invariants>
    Verify: <exact commands>
    Limits: edit only <path> | do not edit files. No prose. Report ≤ 60 lines.

Workers that grab an issue or open an MR/PR record it from inside their
worktree: `agent-link issue|mr <url>` (skip silently if the command is
missing).

No conversation dump. Only what the worker needs to decide and act.

## Report back — match shape to role

Implement / verify / merge (a strict 4-line status is right here):

    STATUS: CLEAN | BLOCKED | PARTIAL
    CHANGED: <path — one line each, or none>
    VERIFY: <command — result>
    BLOCKERS: <unresolved only, or none>

Research spike / scout / claim-check (read-only — 4 lines is too little; the
body is the deliverable, but stay bounded ≤ ~60 lines and lead with evidence):

    STATUS: ANSWERED | PARTIAL | BLOCKED
    FINDINGS:
    - <claim> — evidence (file:line or source)
    - ...
    OPEN: <unknowns / unverified assumptions, or none>
    RECOMMEND: <the answer or next step, 1–2 lines>

Pick the schema in the handoff. Never pad an implement report to look like
findings, or compress a spike into a status line.

## Ledger row (driver notes + final report)

    role=<r> slice=<id> requested_model=<id>:<thinking> resolved_model=<known|unknown> status=<clean|fixed|blocked>
