# `.ai/` — tracked agent working memory

Not throwaway chat scratch. Committed, travels with the repo, indexed by git
branch / run id. Written and read by the `dw-*` skills as the source of truth for
resume points, plan status, and quality assessments.

## Layout

```
runs/<YYYYMMDD-ticket-slug>/      one folder per feature/fix — opened by dw-spec
  SPEC.md    goal, scope, approach           (dw-spec)
  PLAN.md    status table of steps           (dw-plan; rows flipped by dw-build / dw-sync)
  NOTES.md   append-only decision log        (dw-build, dw-sync)

verify/<branch-slug>/             quality artifacts per branch
  explain.md     intent + runnable checks    (dw-explain)
  review.md      multi-axis review           (dw-review)
  verify-run.md  execution evidence          (dw-verify)
  conform.md     drift vs plan/spec          (dw-conform)
  risk.md        blast radius + rollback     (dw-risk)
  prune.md       test redundancy plan        (dw-prune)

handoffs/<YYYYMMDD-HHMM>.md       session continuity          (dw-handoff)
```

## Rules

- **Tracked on purpose** — `git add` and commit these alongside the code.
- Skills own these files; don't hand-edit mid-run.
- Safe to read anytime. To pick up after `/clear`: `dw-resume` reads the active run.
