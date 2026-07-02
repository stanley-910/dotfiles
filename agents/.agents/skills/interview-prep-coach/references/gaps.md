# Demonstrated Gaps (evidence-only, user-owned)

This file is for weaknesses the user has **actually demonstrated in a session** —
never assumptions from background or skill level. The user owns this file and may
edit or delete any entry.

Format per entry:
- `YYYY-MM-DD` — [topic/problem] — one line on what was missed. (flashcards: yes/no)

When a gap is added, offer to send it to the flashcards skill. Plan mode pulls from
this file to target revision.

---

- `2026-06-25` — LC 53 Maximum Subarray (Kadane's) — restart condition: cycled through `running < nums[i]` / `running < nums[0]` before the algebra fixed it at `running < 0`; couldn't initially justify *why* 0 is the threshold. (flashcards: yes)
- `2026-06-25` — Complexity of brute force with `sum(slice)` — called the nested-loop brute force O(n²), missed that `sum(nums[i:j+1])` is hidden O(n), making it O(n³). (flashcards: yes)
- `2026-06-25` — Python slice bounds — needed prompting that `nums[i:j]` excludes `j` (use `nums[i:j+1]`) and that slicing copies (O(k)). (flashcards: yes)
- `2026-06-27` — LC 905 / complexity vocab — (a) attributed `list.pop(j)`'s O(n) to *searching* — it's the shift; index access is O(1) (only `list.remove(value)` searches). (b) called `n × O(n)` work "exponential" — it's polynomial **O(n²)**; exponential = 2ⁿ. (flashcards: no, user declined)
- `2026-06-27` — Loop invariants (concept) — blanked on what a loop invariant *is* when asked to state one for the 905 two-pointer. Recalled the mechanics (write-pointer, swap) but not the formal concept. (flashcards: pending)
- `2026-06-29` — LC 415 Add Strings — built the result with `res = f"{s}{res}"` (O(n) string prepend each step → **O(n²)**); recurring hidden-cost theme. Also couldn't reach the canonical pattern: two *independent* pointers + `while i>=0 or j>=0 or carry` + `divmod` + append-to-list — used a `longer`/`shorter`/`diff` alignment instead. (flashcards: yes — on note)
