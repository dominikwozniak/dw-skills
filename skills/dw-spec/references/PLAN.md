---
run: YYYYMMDD-ticket-or-slug
spec: ./SPEC.md
status: todo # todo | doing | done | blocked
---

# Plan — [title]

## Status table

The first row whose Status ≠ `done` is the resume point (`dw-resume`). Step IDs
are immutable once committed — never renumber a step that already has a commit.

| Phase | Step | Title                 | Status | Commit |
| ----- | ---- | --------------------- | ------ | ------ |
| 1     | 1.1  | [thin vertical slice] | todo   |        |
| 1     | 1.2  | [...]                 | todo   |        |

Status ∈ `todo` | `doing` | `done` | `blocked`. Commit = short SHA once the step
lands.

## Architecture decisions

- [decision + rationale]

## Risks

- [risk + mitigation]

## Verification checkpoints

- [after which step, what to run or observe — commands read from the project]
