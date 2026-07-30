---
run: YYYYMMDD-parent-run-slug
spec: ../SPEC.md
slices: 11 # must equal the number of NN-*.md files — slice-status.sh --check enforces it
---

# Slices — [spec title]

Frontier = every slice whose blockers are all `done`. Numbers are immutable.

| #   | Title   | Status | Blocked by | Blocks | Taken run               |
| --- | ------- | ------ | ---------- | ------ | ----------------------- |
| 01  | [title] | ready  | —          | 03     | —                       |
| 02  | [title] | doing  | —          | —      | YYYYMMDD-child-run-slug |

## Graph

[blocks as an indented tree or arrow list — enough to see the critical path]

## Frontier now

- `01` — takeable immediately.
