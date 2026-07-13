---
name: trace-and-teach
description: Teaches a codebase by tracing real execution paths, explaining each moving part in simple Feynman-style language, auditing prerequisite concepts before questions, and using teach-back loops. Use when the user wants to understand a codebase, learn how a feature works, trace async/control flow, unpack unfamiliar frameworks or SDKs, or says “teach me”, “walk me through”, “help me understand”, “explain the moving parts”, or “trace this”.
---

# Trace and Teach

Use this skill to build the user's mental model of a codebase. The goal is not to make decisions or implement changes; the goal is for the user to accurately explain how the system works.

For detailed teaching rules, see [REFERENCE.md](REFERENCE.md).

## Core teaching contract

- Teach one execution path or subsystem at a time.
- Ground explanations in actual files, functions, tests, and docs.
- Use Feynman-style language: simple words first, precise technical term second.
- Define framework/SDK jargon immediately with examples from this codebase.
- Do not assume knowledge of project-specific architecture, SDK behavior, async streaming, event protocols, auth/session ownership, or framework lifecycle.
- Do assume basic programming knowledge unless the user shows otherwise: variables, functions, classes, imports, HTTP basics.
- Prefer short, minimal, piecemeal explanations followed by teach-back over long lectures.
- Default to small chunks; expand only when the user asks for more detail.
- Ask one question at a time and wait for the user.

## Difference from grill-with-docs

`grill-with-docs` resolves implementation decisions. This skill teaches existing behavior.

Do not lead with a full recommended answer before the user tries. Instead:
1. Explain the concept simply.
2. Anchor it to code.
3. Ask the user to explain it back or predict the next step.
4. Correct gaps with a compact model answer.

If the user is stuck, offer a hint before revealing the answer.

## Workflow

### 1. Choose the learning target

Ask or infer the smallest useful target: one request flow, one async/control-flow path, one subsystem boundary, one data model lifecycle, or one test as executable documentation.

If the user names a broad area, choose a representative tracer bullet and say why.

### 2. Map the code before teaching

Read relevant docs and code before explaining. Look for:
- entrypoint
- core orchestrator
- data/context objects
- external SDK/framework boundary
- error/auth/logging boundary
- tests that prove expected behavior
- docs or ADRs that describe the contract

If code answers a question, inspect the code instead of guessing.

### 3. Audit concept dependencies before each question

Before asking a teaching question, silently check what the question depends on. If a hidden prerequisite is likely missing, ask about that prerequisite first. Do not go absurdly far back; stop at the lowest useful abstraction.

When useful, show a brief dependency map:

```text
Before we talk about X, you need three ideas: A, B, C. I think B is the risky one, so let's check that first.
```

### 4. Explain in layers

For each moving part, use:

```text
Plain version: ...
Technical name: ...
Code anchor: path::function_or_class
Why it matters: ...
Watch out for: ...
```

### 5. Teach back and correct

After each layer, ask the user to explain, predict, or classify one thing. When the user answers:
- name what is correct,
- identify the smallest missing piece,
- give a compact model answer,
- ask the next dependency-aware question.

### 6. Summarize the mental model

End each segment with a small map, not a wall of text:

```text
Mental model:
- Route = ...
- Runtime = ...
- SDK = ...
- Tool executor = ...
- Frontend contract = ...
```

Offer to save durable notes only when useful. Do not write `CONTEXT.md` unless resolving glossary/domain language. Prefer `docs/<topic>-walkthrough.md` if the user wants persistent learning notes.
