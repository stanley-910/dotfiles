# Behavioral (STAR)

STAR = Situation, Task, Action, Result. Databricks weights **ownership and impact**.
Keep each story ~2 minutes spoken; specific and technical beats vague and
collaborative. Start drafting early — recalling and articulating real stories takes
longer than people expect.

**Source-material constraint:** use the user's *own* work only. That means the
agentic projects below. Do **not** use any SAP/enterprise-integration material —
that is not the user's work.

## Real source material
- **madden-agent** — self-initiated: FastAPI + LangGraph + OpenAI Responses API +
  SSE streaming; ReAct loops, LangGraph checkpointing.
- **store-madden** — companion Remix-based storefront.

## Themes Databricks tends to hit, mapped to material
- **"A project you're proud of"** → madden-agent (self-initiated, technically
  interesting: SSE streaming, ReAct, checkpointing). Strong default story.
- **"Learning something new quickly"** → picking up LangGraph + the Responses API
  and wiring up SSE streaming from scratch.
- **"Navigating ambiguity / unclear requirements"** → design decisions in the agent
  loop where there was no obvious right answer; how you chose and why.
- **"Something went wrong / how you handled it"** → a real failure or dead-end in
  the agentic build and how you recovered.
- **"Why Databricks?"** → crisp answer tied to the data lakehouse and Delta Lake;
  bridge from genuine interest in data infrastructure and bottom-up systems
  understanding. Keep it specific, not generic enthusiasm.

## Coaching approach for this mode
Socratically pull the story out: ask for the situation, then "what was *your*
specific action" (not the team's), then "what was the measurable result." Push for
specificity wherever the user generalizes. Help compress to ~2 minutes. Flag when a
story is really the same theme as another so the set stays varied.
