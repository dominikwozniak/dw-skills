---
name: dw-spec
description: >-
  Write a persistent feature/change spec under `.ai/runs/` before planning or coding. Opens with a
  skeleton plus numbered Open Questions and HARD STOPS until you answer them, so wrong assumptions
  surface before they cost a rewrite. Reads stack, commands, and patterns from the project — never
  assumes a framework. Use when starting a new feature, ticket, or non-trivial change, or when
  someone says "spec this out", "write a spec", "define requirements", or invokes "dw-spec".
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

The run folder and the `SPEC.md` frontmatter are **created by a script**, so the id
and frontmatter are derived one way every time — the bug that motivated this was
`.ai/runs/<…-ABC-123-…>` (uppercase) drifting from the lowercase
`.ai/verify/<abc-123-…>`.

1. **Don't clobber an existing run.** Check whether this branch already has one:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/find-active-run.sh"`. If it prints a run
   directory, **continue that SPEC** — only start a new run for a genuinely new unit
   of work; when unsure, ask. (`${CLAUDE_PLUGIN_ROOT}` is the env var Claude Code
   substitutes to this plugin's install dir; the script ships with the plugin, not
   the project repo.)
2. **Create the run:**
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/new-run.sh" <ticket> "<short description>"` —
   pass the ticket from the branch if it encodes one (e.g. `ABC-123`), else `none`.
   It creates `.ai/runs/<YYYYMMDD>-<ticket-lower>-<slug>/SPEC.md` with the frontmatter
   filled (`run / ticket / status: draft / created / branch`), prints the run
   directory, and refuses to overwrite an existing one. The folder uses the lowercased
   ticket so it matches `.ai/verify/<branch-slug>/`; the frontmatter `ticket:` keeps
   the uppercase `ABC-123` your commit / PR subjects use.

Then fill in the SPEC body (below) under the `# Spec — …` heading the script wrote.

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

Copy the body shape from `references/SPEC.md` (`new-run.sh` already wrote the
frontmatter). In this first pass write
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
