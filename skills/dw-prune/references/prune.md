---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
sources: review.md, conform.md # which neighbours fed this; "none — checked from the diff" if standalone
---

# Prune — [title of the change]

Prune plan for the tests around this change: which to keep, merge, or delete. A test is marked
`delete` or `merge` _only_ when a named, retained test still catches its behavior — so production
coverage never drops. `dw-prune` writes this plan first and STOPS; it applies edits only on explicit
consent (batch or per-row), then re-runs the project's test suite and records the result below.

## Verdict

**[prunable | clean | blocked]** — [one line: `n` to delete / `n` to merge, or "every test earns its
place"].

<!-- prunable ⇐ ≥1 merge/delete proposed · clean ⇐ all keep · blocked ⇐ a redundant-looking test has no retainer, so it stays keep -->

## Prune plan

One row per candidate test. `Test` is a real `path:line` (opened via Read or present in the diff).
For `merge` / `delete`, `Retained by` names the test (`path:line`) that still covers the behavior —
mandatory, never blank. "— none —" when there is nothing to prune.

| Action | Test (file:line)        | Behavior covered                   | Retained by (file:line) | Notes                                      |
| ------ | ----------------------- | ---------------------------------- | ----------------------- | ------------------------------------------ |
| delete | `[spec/foo_spec.rb:40]` | [rejects a blank email]            | `[spec/foo_spec.rb:12]` | [exact duplicate of the :12 case]          |
| merge  | `[test/bar.test.ts:30]` | [returns 404 on a missing id]      | `[test/bar.test.ts:18]` | [fold the assertion into the :18 case]     |
| keep   | `[spec/baz_spec.rb:55]` | [the only test for the retry path] | —                       | [stale wording, but uniquely covers retry] |

## Result

[Filled after applying approved edits. Run the project's own test command and record it here.]

- **Applied:** [batch | rows 1, 2 | none — plan only]
- **Test command:** `[project-resolved command]`
- **Suite:** [GREEN — `n` passing, evidence excerpt | RED — failing test + excerpt; prune NOT
  confirmed | UNVERIFIED — command could not be resolved / suite not runnable here]

## Summary

[Lead with the verdict and the counts (keep / merge / delete). One short paragraph: what the prune
buys (less overlap, a faster and clearer suite), the coverage guarantee (nothing deleted without a
named retainer), and anything deliberately out of scope — a stale-but-unique test was kept and
flagged, not rewritten; fixing assertions or logic is implementation, not pruning.]
