---
branch: dw-spine-scripts
base: main
created: 2026-06-20
sources: review.md
---

# Fix — RUN A deterministic spine review

Treatment log for the independent review in `review.md` (verdict: REQUEST CHANGES). The findings sit
almost entirely in one file (`find-active-run.sh`), so they were fixed and verified together in a
single commit rather than one-per-fix.

## Summary

6 fixed (2 blockers cleared), 1 resolved as not-a-defect. Both HIGH bash bugs are fixed and verified
under bash 3.2; the verify-side slug-contract finding needed no code change.

## Applied

| Severity | Location                                            | Finding                                                                                  | Fix commit |
| -------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------- | ---------- |
| high     | `plugins/dw-planning/scripts/find-active-run.sh:50` | Multi-match tiebreak sorted lexically (by description on a same-day tie), not by recency | `7b3560a`  |
| high     | `plugins/dw-planning/scripts/find-active-run.sh:79` | PLAN with no Status column reported "all steps done" — a false green                     | `7b3560a`  |
| medium   | `plugins/dw-planning/scripts/find-active-run.sh:85` | A row with fewer cells than the Status column could shift the parse                      | `7b3560a`  |
| medium   | `scripts/validate-manifests.sh:36`                  | CI checked neither the new run scripts nor slugify.sh copy parity                        | `7b3560a`  |
| low      | `plugins/dw-planning/scripts/find-active-run.sh:50` | Comment asserted a sort property the code lacked                                         | `7b3560a`  |
| low      | `plugins/dw-planning/scripts/slugify.sh:18`         | LC_ALL=C non-ASCII folding was undocumented                                              | `7b3560a`  |

## Deferred

| Severity | Location                                            | Why deferred                                                                                                                                                                                                                              |
| -------- | --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| medium   | `plugins/dw-planning/scripts/find-active-run.sh:38` | Not a defect: `branch:` lives only in SPEC frontmatter (PLAN frontmatter is run/spec/status), so matching `SPEC.md` is the complete contract; the "PLAN.md, else SPEC.md" prose was already corrected to SPEC-only in the wiring commits. |

## Next

Both HIGH blockers cleared and re-verified under bash 3.2 (multi-match recency, no-status error path,
short-row guard, parity check). RUN A is ready to push; a `tests/` harness for these scripts lands in
RUN B (the B3 golden fixtures double as the test).
