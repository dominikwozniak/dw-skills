---
name: dw-verify
description: >-
  Execute grounded scenarios from explain.md with project-native commands and record output,
  evidence, and PASS, FAIL, or INCONCLUSIVE verdicts in .ai/verify. Ask before mutation and never
  claim PASS without output. Use for "verify this change", "prove the fix", or "dw-verify".
argument-hint: "What to verify? (all scenarios, a #, a type, or a priority)"
---

# dw-verify — run the scenarios, record the evidence

Use expanded invocation arguments when available. If the host leaves literal `$ARGUMENTS`, ignore
the placeholder and infer scenario scope from the user's prompt.

You have an `explain.md` full of runnable verification scenarios (or a change that
needs proving). The valuable next step is to actually **run** them — fire the SQL,
hit the endpoint, run the test, probe the edges — and write down what happened. But
that work normally evaporates into the conversation: the next session, or review,
can't see whether anything was actually checked. This skill captures it as a durable
artifact: `verify-run.md`, holding for each scenario the command, the expected
result, the **actual** output, a verdict, and the evidence.

The whole point is **evidence, not assertion**. A row that says PASS with no captured
output proves nothing — it's the same ghost-chasing `dw-explain` warns about, one
step later. So every PASS or FAIL carries its output, and when you genuinely can't
run something you say so (`INCONCLUSIVE`) rather than guessing a verdict.

## Output location

Write to `.ai/verify/<branch-slug>/verify-run.md`. `.ai/` is tracked in git —
verification results are real work documentation, committed alongside the code.

- Branch slug for the folder name —
  `bash "<runtime-dir>/slugify.sh" branch-slug "$(git rev-parse --abbrev-ref HEAD)"`
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the same slug
  `dw-explain` used, so your `verify-run.md` lands beside its `explain.md`.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Input — read `explain.md` first

`explain.md` in the target folder is your **primary input**. Read it and parse its
section **C. Prove it works** — a table of scenarios, one per row:

| # | Type | Pri | Command | Expected | Referent |

Each row is a unit of work: run `Command`, compare against `Expected`. `Type` and
`Pri` drive how and in what order you run them; `Referent` is what grounds the
scenario in real code. Also read `review.md` / `conform.md` if they sit beside it —
they tell you what a reviewer flagged, which is where your attention (and any P0
re-runs) should concentrate.

**Self-contained fallback.** `dw-verify` does not depend on `dw-explain` having run.
If there is no `explain.md`:

- Prefer to **derive a minimal scenario set from the diff yourself** — resolve the
  change (next section), find the obvious referents (a new route, a changed column, a
  touched function), and write a few P0 scenarios the same way `dw-explain` would.
- If you genuinely can't ground anything to run, **say so and suggest running
  `dw-explain` first** — but still **write `verify-run.md`**, recording that no
  scenarios could be grounded (an honest empty / INCONCLUSIVE result is itself a
  finding). Never finish a run with no artifact.

## Resolve the change (three input shapes)

The request — which change, and which scenarios to run — may arrive as `$ARGUMENTS`.
You need the diff both to locate the right branch-slug folder and to derive scenarios
in the fallback. Accept any of three shapes; pick by what the user pointed at, else
default to the working diff:

1. **Working diff** (default): `git diff $(git merge-base HEAD <base>)` (base is
   usually `main`; read it from the project's git conventions if declared).
2. **Branch vs an explicit base**: `git diff <base>...HEAD`.
3. **PR**: `gh pr diff <number>` (or `gh pr diff` on the current branch's PR).

## Read the project's commands (don't hardcode a stack)

A scenario's `Type` is a technology-agnostic label; the **command that realises it**
is always the project's real command. Never assume a framework or invent a runner.
Instruction precedence: `DW.local.md` → legacy `CLAUDE.local.md` → `AGENTS.md` → `CLAUDE.md` →
autodetection. Discover in this order:

1. **Declared block** — `## Commands` / `## Project specifics` from the instruction files (test /
   lint / run / db-console / server URL /
   run-snippet). Reuse whatever the project documents.
2. **Manifests / scripts** — `package.json` scripts, `Gemfile` + `bin/`, `Makefile`,
   `Procfile`, `composer.json`, `pyproject.toml`, … (also how you detect the stack:
   Gemfile → Ruby, package.json → Node, go.mod → Go).
3. **The code itself** — when neither declares it, infer from what you can read.

If a command can't be resolved, the scenario is `INCONCLUSIVE` — name the assumption
you'd need. Never silently guess a command, and never paper over the gap with a
made-up one.

## The execution guard

This is where `dw-verify` differs from `dw-explain`: you are not writing scenarios,
you are **running** them — against whatever environment this session can reach. Run
the wrong thing and you can mutate real data. So classify every scenario before you
run it.

**Read-only → auto-run.** A `SELECT`, a `GET`, a test suite, a console read, a CLI
that only reports — these have no side effects worth guarding. Run them and capture
the output.

**Mutating → confirm first.** An `INSERT` / `UPDATE` / `DELETE`, a `POST` / `PUT` /
`DELETE`, a destructive CLI command — these change state. **Ask the user before
running**, and prefer a form that can't harm real data:

- a database transaction you roll back, or a disposable / test database;
- a staging or sandbox base URL, or a throwaway record;
- a dry-run flag or a sandbox directory.

Never silently mutate real data to make a scenario pass. If you can't run a mutating
scenario safely and the user doesn't confirm, it's `INCONCLUSIVE` — a correct
outcome, not a failure of the run. See `references/execution-safety.md` for the
per-type (db / http / cli) playbook.

Two more rules hold for every scenario:

- **Never PASS without captured output.** Evidence is mandatory — the row, the status
  code, the assertion that passed. "Looks right" is not a verdict.
- **Run only what's grounded.** Honour the cluster's anti-hallucination invariant:
  execute only scenarios anchored to a real referent. Never invent a command or a
  scenario, and never promote an `explain.md` **section E (Open questions)** row to a
  run — those are explicitly ungrounded.

## Assign a verdict

Every scenario ends in exactly one verdict:

- **PASS** — actual output matches `Expected`, with the output attached.
- **FAIL** — actual output contradicts `Expected`, with the output attached.
- **INCONCLUSIVE** — you couldn't run it (missing env, unresolved command, no
  permission), the output was ambiguous, or it was a mutating scenario you couldn't
  run safely without confirmation.

`INCONCLUSIVE` is first-class: don't force a PASS / FAIL when you have no evidence.
See `references/verdict-rubric.md` for the full rubric and tie-breakers.

## Workflow

### 1. Locate the input

Resolve the branch-slug and look for `.ai/verify/<branch-slug>/explain.md`. Read it
and any `review.md` / `conform.md` beside it. If there's no `explain.md`, fall back to
deriving scenarios from the diff (see Input).

### 2. Parse and order the scenarios

Walk section C into a list of rows (`#`, type, pri, command, expected, referent). Run
in priority order: **P0 → P1 → P2**. If `$ARGUMENTS` names a specific scenario `#`, a
type (e.g. `db`), or a priority (e.g. `P0`), run only those; otherwise run them all.

### 3. Run each scenario (apply the guard)

For each row: classify read-only vs mutating; resolve the concrete command from the
project; run it (auto for read-only, confirm for mutating); capture the actual output
as evidence.

### 4. Assign the verdict

PASS / FAIL / INCONCLUSIVE per the rubric — never PASS without the output in hand.

### 5. Write `verify-run.md`

Copy the shape from `references/verify-run.md`. One row per scenario:
`# · Type · Pri · Command · Expected · Actual · Verdict · Evidence`. Keep evidence to
a meaningful excerpt (the decisive line, the status code), not a wall of logs.

### 6. Summarise and finalize

Add a summary line with the counters — `PASS: n · FAIL: n · INCONCLUSIVE: n` — and
note any mutating scenarios left unrun pending confirmation. Tell the user where the
artifact landed, then the connector line:

> **Next:** consider `dw-risk` — it maps the blast radius and follow-ups for the
> change you just verified.

## The verify-run.md shape

`references/verify-run.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created` / `explain`) plus the results table
(`# · Type · Pri · Command · Expected · Actual · Verdict · Evidence`) and a summary
line. It's a logical extension of `explain.md`'s section C — the same rows, now with
`Actual`, `Verdict`, and `Evidence` filled in.

## References

- `references/verify-run.md` — the artifact template. Copy this shape every run.
- `references/execution-safety.md` — read before running anything that might mutate
  state: how to tell read-only from mutating per type, and the transaction / sandbox
  recipes that let you run a mutating scenario safely.
- `references/verdict-rubric.md` — read when assigning verdicts: exactly when a
  scenario is PASS, FAIL, or INCONCLUSIVE, and how to break ties.
