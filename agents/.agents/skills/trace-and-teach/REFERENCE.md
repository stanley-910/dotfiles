# Trace and Teach Reference

## Question dependency audit

Before asking a teaching question, silently build this graph:

```text
Question I want to ask:
- What understanding am I testing?

Depends on:
- prerequisite concept A
- prerequisite concept B
- prerequisite concept C

For each prerequisite:
- Has the user already demonstrated it?
- Is it visible in the code we just read?
- Is it likely hidden behind framework/SDK magic?
```

If a hidden prerequisite is likely missing, ask about that prerequisite first.

Examples of hidden dependencies:

- Async stream questions may depend on async iterators, server-sent events, and why a response can arrive in chunks.
- Tool-calling questions may depend on the idea that the model can ask the backend to run code, then continue after receiving the result.
- Auth/session questions may depend on the difference between conversation ownership, store session id, anonymous id, and request context.
- SDK questions may depend on the boundary between what the SDK owns and what project code still owns.

Do not go too far back. Assume basic programming knowledge unless evidence says otherwise.

## Language rules

Use simple words first:

```text
Plain version: The SDK is the traffic controller. When the model asks for a tool, the SDK helps pause, run the tool, send the result back, and continue.
Technical term: tool orchestration.
Code anchor: src/agent/runtime.py::stream_message
```

Avoid unsupported abstraction:

- Bad: “The SDK abstracts orchestration of response continuations.”
- Better: “The SDK now owns the loop where the model asks for a tool, waits for the tool result, then continues answering.”

Prefer verbs like:

- owns
- hands off
- turns into
- carries
- waits for
- sends back
- wraps
- checks

Avoid acronyms until expanded once. Define terms like stream, event, guardrail, session, context, tool call, runner, and hook at first use in a teaching segment.

## Good teach-back prompts

Default to short, self-contained teaching turns: one concept, one code anchor, one small checkpoint. Avoid making the user scroll back to recover needed context.

Use prompts that test one piece at a time:

- “In your own words, what does this layer own?”
- “What happens next if the model asks for a tool?”
- “Which object carries the session id here?”
- “Where does the frontend contract stop caring about SDK internals?”
- “Why does the backend need a second model turn after the tool finishes?”
- “Which part is stable for the frontend, and which part is SDK-internal?”

Avoid:

- “Do you understand?”
- “Explain the whole system.”
- Questions whose answer depends on unread code.
- Questions that smuggle in undefined terms.

## Correction pattern

When the user answers:

```text
You have the main idea: ...
The missing piece is: ...
Simple version: ...
Code anchor: ...
Next checkpoint: ...
```

Keep corrections narrow. Do not restart the whole explanation unless the user asks.

## Refusal gates

Do not proceed deeper when:

- the user’s answer shows a missing prerequisite,
- the explanation depends on unread code,
- the term being used is overloaded and unresolved,
- the user asks to slow down or simplify.

In those cases, step back one layer and teach the prerequisite first.

## Durable notes

This skill may create learning notes only when the user wants them.

- Use `docs/<topic>-walkthrough.md` for persistent system walkthroughs.
- Use `CONTEXT.md` only for glossary/domain language, never implementation notes.
- Use ADRs only for durable decisions, not for teaching summaries.
