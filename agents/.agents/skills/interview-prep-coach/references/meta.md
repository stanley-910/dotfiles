# Skill Self-Tuning (observation log)

This skill should adapt to the user over time. This file is where the agent records
observations about **how the skill itself is working** for the user — distinct from
`gaps.md`, which is about the user's *knowledge*. This file is about the *skill's
design and fit*.

## The rule: observe first, act on a confirmed pattern

Do **not** rewrite the skill the moment the user expresses one frustration — a
preference voiced in a single bad moment isn't always a real, durable preference.
But do **not** ignore a recurring pattern either.

1. **First signal** — if something seems to hinder the user's learning, annoy them,
   or repeatedly come up (a mode that isn't landing, hint timing that's off, a track
   that's too heavy/light, tone that's not working), **note it here** with the date
   and what happened. Take no structural action yet.
2. **Confirmed pattern (2–3 instances)** — once the same issue recurs 2–3 times,
   **propose a specific change to the user** and explain what you'd alter and why.
3. **Only edit after a yes.** Never silently mutate the skill. Surface the proposed
   change, get explicit confirmation, then edit the relevant file (SKILL.md or a
   reference) and note the change here.

The user owns this file and may edit or delete entries. They can also request a
change directly at any time, which skips the observation threshold.

## What's in scope to tune
- Mode behavior (Quiz/Review/Plan/Mock/Flashcards) and whether each is useful.
- Hint timing and how much push is right when stuck.
- Socratic intensity — too aggressive, not aggressive enough.
- Pacing and track balance in `weekly-plan.md`.
- Anything in the reference files that's stale or not fitting.

Always preserve the core commitments unless the user *explicitly* overrides them:
**no competence priors**, **Socratic by default**, **hints after real effort**,
**evidence-only gap logging**.

## Observation entries

Format: `YYYY-MM-DD` — observation — (status: noted / pattern-confirmed / changed)

---

- `2026-06-25` — In a Quiz/Plan session on LeetCode 53, bundled multiple sub-questions into one Socratic turn (two DP properties + a divide-and-conquer tangent + the recurrence). User reported it was "too much to juggle." Single-question, one-step-at-a-time turns landed better. Watch whether Socratic turns need a hard one-question-at-a-time cap. — (status: noted)
- `2026-06-26` — Plan/networking session: gave the user a large annotated roadmap + a multi-item research list + multiple resource options across several turns. User reported the basic terms felt "overlapping" and asked for "a singular place to start." Breadth/menus overwhelm; the user wants ONE anchored starting point and a single coherent mental model, not a list. This rhymes with the 2026-06-25 bundling signal — both are "too much surface area at once." Resolution that landed: one unifying analogy + "close other sources, use one path." If this recurs a third time, propose a durable rule: in maintenance gear, default hard to a single concept/resource/question per turn and offer breadth only on request. — (status: noted, 2nd instance — one more confirms the pattern)
- `2026-06-29` — Plan/"give me the syllabus" request: I answered with a multi-block hour plan **and** a 4-option track picker (DDIA / Go / LeetCode / Blend). User declined the picker outright and steered to "just give me an easy one, 15 min max." **Third instance** of the "menus/breadth overwhelm — wants ONE anchored next action" pattern (after 6/25 bundling, 6/26 breadth). Pattern confirmed. Proposed durable rule to the user: *in maintenance gear, default hard to a single concrete next action per turn (one problem / one concept / one question); offer breadth/options only when the user explicitly asks to choose.* — (status: pattern-confirmed — awaiting user yes before editing SKILL.md)
- `2026-06-29` — Over-read three `gaps.md` complexity entries as a "recurring hidden-cost blind spot" and proposed a standing Plan-mode priority. User corrected: writing the dumbest solution first is **intentional strategy**, not a gap. Lesson: don't synthesize a few evidence entries into a "weakness" and propose structural focus without checking the user's intent first — it brushes against the no-priors commitment. Withdrew the proposal; saved working-style to `feedback-brute-force-first-by-design` memory. — (status: noted)
- `2026-06-29` — DSA note-creation routine got heavily refined this session (user-directed, which skips the observation threshold): added the "Finished-problem routine" to SKILL.md; notes now lean/optional, cards live in a `%%` fence not a `### header`, the user's actual code is the source of truth (no tidying), and card syntax is delegated to the `/flashcards` skill. Encoded in SKILL.md, the `DSA Problem.md` template, and `feedback-dsa-problem-note-format` memory. — (status: changed)
