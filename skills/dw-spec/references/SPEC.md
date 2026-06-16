---
run: YYYYMMDD-ticket-or-slug
ticket: ABC-123 # or: none
status: draft # draft | open-questions | ready
created: YYYY-MM-DD
branch: my-feature-branch
---

# Spec — [title]

## TLDR

- **What:** [1–2 sentences: what we're building or changing]
- **Why:** [the value, or the problem being solved]

## Open Questions (HARD STOP) — remove before finalizing

> Include this block in the skeleton when a wrong assumption would force a
> rewrite — data shape, scope boundary, integration point, replace-vs-extend.
> **STOP here. Do not research, plan, or code until every question is answered.**
> Delete this section once all are resolved.

- **Q1:** [critical unknown — binary or multiple-choice where possible]
- **Q2:** [...]

## Scope

**In:**

- [what this change includes]

**Out:**

- [explicitly not doing — this list guards against scope creep]

## Approach

[High-level shape. Cite REAL patterns to follow, by path
(`path/to/existing_sibling.ext` — confirmed via Read/grep). Never invent a
pattern or a file that isn't there.]

## Boundaries

- **Always:** [invariants the implementation must hold]
- **Ask first:** [decisions that need a human before proceeding]
- **Never:** [hard prohibitions — irreversible or out-of-bounds actions]

## Success criteria

- [ ] [observable, checkable outcome]
- [ ] [verification step — command read from the project (test / lint / run)]
