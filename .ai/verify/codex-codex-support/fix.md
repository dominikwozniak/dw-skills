---
branch: codex/codex-support
base: main
created: 2026-07-13
sources: review.md
---

# Fix — blockers pass (dw-fix blockers)

## Summary

All 3 high findings from `review.md` (verdict: request-changes) fixed, one commit each; the coupled
medium `Move to:` security finding was fixed in the same commit as the env-guard blocker, as the
review itself prescribed. Self-tests extended to pin each fix (env guard 36/36, hook runtime 13/13,
`pnpm validate:artifacts` / `validate:docs` / `validate:compat` all green).

## Applied

| Severity | Location                               | Finding                                                                                          | Fix commit                                                                                                                                 |
| -------- | -------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| high     | `.claude/hooks/block-env-access.sh:56` | apply_patch fell through the header scan into the whole-body token scan (false-blocks)           | `bc4ea71` — apply_patch branch made terminal; both copies + 5 new test cases                                                               |
| medium   | `.claude/hooks/block-env-access.sh:54` | header scan missed `Move to:` rename targets; quoted target bypassed the guard                   | `bc4ea71` — `Move to:` arm added, surrounding quotes stripped (fixed with the blocker above, as one change per the review's suggested fix) |
| high     | `.claude/hooks/hook-common.sh:67`      | `dw_hook_local_command` no longer extracted the backticked command; annotations broke every edit | `775e91a` — first backtick-delimited span extracted when present; both copies + regression test                                            |
| high     | `skills/dw-bootstrap/SKILL.md:96`      | Codex bootstrap installed `codex-hooks.json` verbatim with no prune step                         | `9fea55d` — prune instruction added to step 5 and the Templates list, mirroring the settings.json wording                                  |

## Deferred

All medium / low findings in `review.md` outside the coupled `Move to:` fix — blockers mode stops at
critical / high by design; the rest awaits the next `dw-fix` pass after re-review.

## Next

Re-run `dw-review` to confirm the verdict flips clean, then continue the quality pass
(`dw-fix` for the remaining medium/low worklist, `dw-explain` → `dw-verify`).
