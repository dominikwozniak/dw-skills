---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
sources: review.md # which neighbours fed this; "none — checked from the diff" if standalone
---

# Conform — [title of the change]

Conformance check: does this change match the repo's existing, pre-committed patterns? Every drift
cites both the changed line and the pre-existing referent it diverges from (confirmed via `git log` to
pre-date this change). A divergence with no established precedent is _not_ drift — it goes under
No-precedent notes. `dw-conform` writes this before the change merges.

## Verdict

**[drifts | minor-drift | conforms]** — [one line: the must-align drifts, or "matches the repo"].

<!-- drifts ⇐ any high · minor-drift ⇐ only medium/low · conforms ⇐ none -->

## Drift findings

Where the change diverges from an established pattern. Location is `path:line` in the change; Pattern
referent is a pre-existing `path:line` the change should have followed. "— none —" when it conforms.

| Severity | Location      | Drift                                               | Pattern referent (pre-existing) | Suggested alignment                   |
| -------- | ------------- | --------------------------------------------------- | ------------------------------- | ------------------------------------- |
| high     | `[path:line]` | [raw `fetch`; bypasses the shared HTTP client]      | `[lib/http.ts:12]`              | [route the call through `lib/http`]   |
| medium   | `[path:line]` | [returns a bare object; siblings return a Result]   | `[app/services/foo.ts:30]`      | [wrap in the project's `Result` type] |
| low      | `[path:line]` | [snake_case filename in an otherwise camelCase dir] | `[src/fooBar.ts]`               | [rename to camelCase]                 |

## No-precedent notes

First-of-their-kind areas — a new concern with no existing sibling to conform to, so _not_ drift.
Recorded here for honesty, not as findings.

- [`[path]` — first [thing of this kind] in the repo; no precedent to compare against. OR "none —
  every changed area had an established precedent."]

## Summary

[Lead with the verdict and the must-align drifts. One short paragraph: how well the change fits the
repo, the single most important divergence to align first, and anything deliberately out of scope
(internal quality / bugs belong in `review.md`, not here).]
