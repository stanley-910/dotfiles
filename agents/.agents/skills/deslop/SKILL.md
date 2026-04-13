---
name: deslop
description: Review the diff against main and remove AI-generated code slop so changes match the surrounding codebase style.
---

Check the diff against main and remove AI-generated slop introduced in this branch.

Remove:
- Extra comments that are unnatural or inconsistent with the file
- Unnecessary defensive checks or try/catch blocks that do not fit trusted codepaths
- Casts to any used to bypass type issues
- Any other style inconsistent with the surrounding code

At the end, respond with only a 1-3 sentence summary of what you changed.
