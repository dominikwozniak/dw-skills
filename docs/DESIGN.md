# Design notes

Why the skills are shaped this way. The [README](../README.md) is the short version — what each
skill does; this is the _why_ behind the shape.

## The failure modes these skills target

Each skill answers one failure mode of agentic coding. The
[README](../README.md#-why-these-skills-exist) maps each mode to the skill that kills it. The design
choices below are what make those answers hold:

| Failure mode                              | Design answer                                                 |
| ----------------------------------------- | ------------------------------------------------------------- |
| Context dies on `/clear` or a handoff     | Plans/reviews persist as tracked `.ai/` files, not in context |
| Agent runs on a wrong assumption          | HARD STOP gates surface unknowns before any code              |
| "Done" is claimed but never proven        | Verify runs real commands and records the real output         |
| The plan silently drifts from the code    | One writer, branch-matched runs, immutable step ids           |
| One skill grows into a do-everything blob | One skill, one job — they compose through `.ai/`, not chains  |

Each section below states the choice in one line, then the detail.

## Persistence lives in the skill, not a wrapper

**The plan is on disk, not in the model's head.** Each `SKILL.md` writes its own `.ai/` paths as part
of its procedure — there's no `.claude/commands/` glue layer translating intent into a file location.
Plans and reviews land automatically and travel with the installed plugin, so they survive a `/clear`,
a new session, or a handoff. A workflow whose plan lives only in context is one you can't reliably
resume or verify — that's the core problem the catalog solves.

## `.ai/` is tracked, one folder per task, no central index

**Artifacts are real work documents, committed with the code — not scratch.** The layout is deliberate:

- **No shared index file.** A central registry becomes a merge-conflict magnet once tracked. Discovery
  is by directory name + per-file frontmatter, so two branches never fight over one file.
- **One folder per task** (`.ai/runs/<id>/`, with a unique slug) — parallel branches and worktrees
  don't collide.
- **Branch-matched resume.** A run records its branch; resume globs the runs, matches the current
  branch, and reports the first not-`done` step. Deterministic — no scrollback archaeology.
- **The commit column is the sync.** Each plan step carries its commit SHA; committed step ids never
  renumber.
- **Archive on PR, don't delete.** Verification notes outlive the review session.

## Technology-agnostic by construction

**No stack knowledge is hardcoded — every command is read from your project.** A skill finds the
commands it needs (test, lint, run, db-console, server URL) in this order:

1. a declared `## Commands` / `## Project specifics` block in `CLAUDE.md` / `AGENTS.md`,
2. then manifests and scripts (`package.json`, `Gemfile` + `bin/`, `Makefile`, `Procfile`, …),
3. then the code itself.

Stack is detected by which manifest is present, never branched on by name. With no declared commands a
skill auto-detects and **states its assumption, asking when ambiguous** — it never guesses silently.

Verification scenarios are _typed_, so the skill stays stack-neutral and the project fills in the
concrete command:

| Scenario type | Resolves to (example)                |
| ------------- | ------------------------------------ |
| `db`          | a query against a real schema column |
| `http`        | a request to a real route            |
| `cli`         | a binary invocation                  |
| `console`     | a REPL / language-console check      |
| `test`        | the project's own test command       |

Every command is grounded in something that exists in the repo (a route, a column, a file opened by
Read), so nothing is fabricated. Stack-specific examples live in `references/`, marked as examples —
never as skill logic.

## Thin harness, fat skills

**The intelligence lives in the markdown, not in glue code.** A skill's weight tracks its procedure,
not a line budget; bulky detail loads on demand from `references/`.

| Skill weight            | What's in it                                 |
| ----------------------- | -------------------------------------------- |
| trigger-only            | description + a pointer                      |
| procedural + references | process in the body, detail in `references/` |
| procedural-standalone   | full process inline                          |

The harness stays thin, so every model upgrade improves the skills for free. This shape is the direct
application of **"Fat Skills"** (Garry Tan) — see [Inspiration](#inspiration--further-reading) below.

## Composable, not chained

**Skills stay separate and connect through artifacts — never a forced sequence.** Different jobs,
different inputs, different guards (a multi-axis review is not the same job as a pattern-conformance
check). Three light links connect them:

1. **Shared artifacts** in `.ai/verify/<branch-slug>/` — a skill reads its neighbours' outputs when
   they exist (verify reads explain's scenarios; risk reads review + conform). The strongest link:
   deterministic, and it survives `/clear`.
2. **A "Next:" pointer** at the end of each skill body, plus optional in-body delegation.
3. **The README task-router table** — a thin index, not a driver.

The catalog never _depends_ on external skills (they might change or vanish). Composing with outside
tools is optional — which is why a full review skill ships here even though other reviewers exist.

## Diagnosis vs treatment — the one writer in the quality pipeline

**The auditors only read; one skill writes.** `dw-review`, `dw-conform`, `dw-explain`, `dw-verify`,
and `dw-risk` diagnose a change and record findings under `.ai/verify/<branch-slug>/` — none edits
code. That keeps the record honest: an auditor that also patched things would be tempted to
under-report what it couldn't fix.

`dw-fix` is the single writer. It applies the recorded findings — never inventing work outside them —
with `dw-build`'s discipline: minimal slice, run the check, one commit per finding, mark it resolved.
It stays inside the thesis three ways:

- **Human-invoked, not a loop** — it treats the findings in front of it and stops.
- **Issues no verdict** — re-running the auditor on the fixed code is what confirms it's clean, so the
  thing that grades the work is never the thing that wrote it.
- **Severity-gated** — `blockers` (the critical/high findings) are fixed first, then it stops for a
  re-audit, so the other checks never run against code a review already flagged broken. The
  lower-severity findings are then fixed in one batch on a stable picture.

## Explicit-only skills

`dw-bootstrap`, `dw-handoff`, `dw-prune`, `dw-sync`, and `dw-setup-precommit` are invoked by name and
never auto-trigger — they scaffold a repo, install shared tooling, compact or mutate state, or act on
an explicit drift signal, so the model shouldn't reach for them unbidden. Everything else can be
model-invoked when the task fits.

Claude expresses this with `disable-model-invocation: true`; Codex uses the matching
`agents/openai.yaml` policy. `pnpm validate:compat` requires exact parity.

## One corpus, two hosts

`skills/` and `scripts/runtime/` are the only sources of truth. Codex installs one aggregate root
plugin with real directories; Claude installs three selective packages whose symlinks are
materialized by its installer. Skills resolve runtime helpers relative to their loaded `SKILL.md`,
not through a host-specific environment variable. Shared project instructions live in `AGENTS.md`
and private machine context in `DW.local.md`; Claude files are thin imports.

## Loops vs persistence — why these skills don't auto-run

**The catalog chooses persistence plus a human gate over an autonomous loop.** The field is drifting
toward agents that prompt themselves — file a PR, review it, address the comments, trigger the next,
with no human in the seat. A loop that takes a wrong turn doesn't waste one step; it compounds,
multiplying both the error rate and the token burn for as long as it runs unwatched. The value here —
a plan that survives `/clear`, a review tied to real `file:line`s, a "done" that was actually run —
needs none of that. **The HARD STOP is the feature, not a gap waiting to be automated away.**

A bounded loop _could_ fit one day, but only as an opt-in, explicit-invoke conductor that reuses the
existing skills (each still gated) — never a background process that merges on its own.

And it must not become a zoo of personas. Hard-coding an `adversarial-reviewer`, a `security-reviewer`,
an `explorer` freezes flexibility the model already has — it builds the context it needs dynamically.
That's why `dw-review` weighs all five axes — correctness, readability, architecture, security,
performance — in **one** skill, not five personas handing a diff around. The unit is the **job**, not
the persona doing it.

## Inspiration & further reading

- **Fat Skills** — Garry Tan, on skills that carry their own process instead of being thin wrappers:
  <https://x.com/garrytan/status/2042925773300908103>. The "Thin harness, fat skills" section above is
  the direct application.
- **Anthropic — Agent Skills** — the official concept these build on:
  <https://docs.claude.com/en/docs/agents-and-tools/agent-skills>.
