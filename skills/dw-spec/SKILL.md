---
name: dw-spec
description: >-
  Write a persistent feature/change spec under `.ai/runs/` before planning or
  coding. Opens with a skeleton plus numbered Open Questions and
  HARD STOPS until you answer them, so wrong assumptions surface before they
  cost a rewrite. Reads stack, commands, and patterns from the project — never
  assumes a framework. Use when starting a new feature, ticket, or
  non-trivial change, or any time someone says "spec this out", "write a spec",
  "define requirements", "let's plan before building", or invokes "dw-spec".
  Prefer this over diving straight into code for anything non-trivial.
argument-hint: "What feature or change are you speccing?"
---

# dw-spec — write a persistent, gated specification

Turn a request into a durable `SPEC.md` that survives `/clear`, travels with the
repo, and feeds `dw-plan` / `dw-build`. The job is not to write everything at
once — it is to **force the unknowns to the surface before any code is written**,
then capture the agreed shape of the work.

## Output location

Write to `.ai/runs/<id>/SPEC.md`. `.ai/` is tracked in git — specs are real work
documentation, committed alongside the code (not throwaway, not gitignored).

Run id = `<YYYYMMDD>-<ticket-or-slug>` (e.g. `20260616-ABC-123-password-reset`):

1. Date: `date +%Y%m%d` (local time).
2. Branch: `git rev-parse --abbrev-ref HEAD` — record it in frontmatter so
   `dw-resume` and `dw-handoff` can match this run to the branch later.
3. Ticket/slug: take the ticket from the branch name if it encodes one (e.g.
   `ABC-123-...`); otherwise kebab-case the feature title.
4. Collision: glob `.ai/runs/*/`. If a run for this branch or ticket already
   exists, **continue it — do not clobber an existing SPEC.** Only create a new
   folder for a genuinely new unit of work. When unsure, ask.

```bash
mkdir -p .ai/runs/<id>
```

## Workflow

### 1. Gather context (no assumptions about the stack)

- Read the request (it may arrive as `$ARGUMENTS`) and any linked ticket / PR /
  issue.
- Read the project's own conventions — don't guess them:
  - `CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` → `## Project specifics`,
    `## Commands`, `## Git conventions` (test / lint / run / db / server).
  - Manifests if no block is declared (`package.json` scripts, `Gemfile` +
    `bin/`, `Makefile`, `Procfile`, `pyproject.toml`, …) — their presence detects
    the stack.
- Scan the repo for **real sibling patterns** the work should follow, and note
  them by path (you'll cite them in Approach). Confirm each with `Read` / `grep` —
  never reference a file or command you haven't verified exists.

If a command or stack fact can't be found, **state the assumption you're making**
and ask, rather than guessing silently.

### 2. Write the skeleton — TLDR + Scope + Open Questions only

Copy the shape from `references/SPEC.md`. In this first pass write
**only** the TLDR, a rough Scope (in/out), and the **Open Questions** block. Do
not fill in Approach, Boundaries, or Success criteria yet — they depend on the
answers.

Scan the request for **critical unknowns**: decisions where a wrong guess would
force you to rewrite large parts of the spec (data shape, scope boundary,
integration point, which existing thing this replaces vs. extends). List them as
`Q1`, `Q2`, … — one per line, short, binary or multiple-choice where possible.

### 3. HARD STOP — present the skeleton and wait

Show the user the skeleton with the numbered questions and **stop**. Do not
research further, design, write code, or fill the rest of the spec. This gate is
the entire point of the skill: a five-minute answer now is cheaper than a rewrite
(or shipped-wrong code) later. The model's instinct is to plough ahead on a
plausible guess — resist it here.

If there are genuinely no critical unknowns, say so explicitly and let the user
confirm before proceeding — don't invent filler questions, but don't skip the
gate silently either.

### 4. Fill in from the answers

Apply the answers, then delete the Open Questions block. Complete the remaining
sections:

- **Scope (in / out)** — sharpen; the **out** list guards against scope creep.
- **Approach** — the high-level shape, citing the real sibling patterns from
  step 1 by path. Say what to follow, not how to type it.
- **Boundaries** — Always / Ask-first / Never: the implementation's guardrails.
- **Success criteria** — observable, checkable outcomes. Where verification runs
  a command, use the project's command (read in step 1), not an assumed one.

If new critical unknowns surface while filling in, re-run the gate (step 3) for
just those questions.

### 5. Confirm and finalize

Show the finished spec, confirm it matches intent, write it to
`.ai/runs/<id>/SPEC.md`, and set frontmatter `status: ready`.

**Next:** run `dw-plan` to break this spec into a verifiable `PLAN.md` in the
same run folder.

## The SPEC shape

`references/SPEC.md` is the exact shape to copy — frontmatter
(`run/ticket/status/created/branch`) plus TLDR · Open Questions (HARD STOP) ·
Scope · Approach · Boundaries · Success criteria. Keep it lean: a spec is a shared
understanding, not a compliance document. Detail that belongs to code review or
risk analysis lives in other skills, not here.

## Downstream templates

The run folder is filled in by later `dw-planning` skills, each owning its own
file:

- `dw-plan` writes `PLAN.md` (status table — the resume point) from
  `references/PLAN.md`.
- `dw-build` appends `NOTES.md` (append-only log) from
  `references/NOTES.md`.

Both templates ship here so the whole pipeline copies one consistent set of
shapes. `dw-spec` itself writes only `SPEC.md`.
