---
name: leetcode-solutions-path
description: "Where the user's persisted LeetCode solution files live (for Review mode)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 95b85aa6-83e3-4b48-ad0d-3306eae82f5e
---

The user solves LeetCode in Neovim via **leetcode.nvim**, which **persists** solution files (not a cache — they survive across days) at:

`/Users/stanwang/.local/share/nvim/leetcode/`

- Files are named `<id>.<slug>.py` — e.g. `53.maximum-subarray.py`. Locate a problem by its number.
- Only the code between the `# @leet start` and `# @leet end` markers is the user's; the long import block, `ruff.toml`, `pyrightconfig.json`, and `.ruff_cache/` are scaffolding to ignore.
- A file existing does NOT mean a real attempt exists — leetcode.nvim writes scratch/boilerplate too (e.g. an early `1.two-sum.py` held only `print()` lines). Check the marker region before reviewing.

**How to apply:** In Review mode ("I solved X, review it"), read the matching file here directly instead of asking the user to paste. Relates to [[interview-timeline]] (the prep this supports).
