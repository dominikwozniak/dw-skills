# Design notes

Why these skills are built the way they are. The [README](../README.md) gives the short version;
this is the longer rationale.

## The failure modes these skills target

Agentic coding fails in recognisable ways, and each design choice below is a direct answer to one of
them: the plan that lived only in the model's context and vanished on `/clear`; the confident wrong
assumption that surfaced only after the rewrite; the "done" that was never actually run; the plan that
drifted from the code until neither described reality; the change that merged on a glance. The
[README](../README.md) maps each failure mode to the skill that kills it — the sections below explain
_why_ the skills are shaped the way they are to make those guarantees hold.

## Persistence lives in the skill, not a wrapper

Each `SKILL.md` bakes its own `.ai/` output paths into its procedure. There is no
`.claude/commands/` glue layer translating intent into a file location. Plans and reviews land on
disk automatically and travel with the installed plugin — surviving a `/clear`, a new session, or a
handoff to another agent. This is the core problem the catalog solves: a workflow whose plan only
ever lives in the model's context is one you cannot reliably resume or verify.

## `.ai/` is tracked, one folder per task, no central index

Artifacts are real work documents, committed alongside the code they describe — not throwaway
scratch. The layout is deliberate:

- **No shared index file.** A central registry becomes a merge-conflict magnet once tracked.
  Discovery is by directory name + per-file frontmatter, so two branches never contend for one file.
- **One self-contained folder per task** (`.ai/runs/<id>/`) with a unique slug — parallel branches
  and worktrees don't collide.
- **Branch-matched resume.** A run records its branch in frontmatter; resume globs runs, matches the
  current branch, and reports the first not-`done` step. Deterministic — no scrollback archaeology.
- **Sync is the commit column.** Each plan step carries its commit SHA; committed step ids never
  renumber.
- **Archive, not delete, on PR.** Verification notes outlive the review session.

## Technology-agnostic by construction

Skills are pure procedures — no stack knowledge is hardcoded. The commands a skill needs (test,
lint, run, db-console, server URL) are read _from the project_, in order:

1. a declared `## Commands` / `## Project specifics` block in `CLAUDE.md` / `AGENTS.md`,
2. then manifests and scripts (`package.json`, `Gemfile` + `bin/`, `Makefile`, `Procfile`, …),
3. then the code itself.

Stack is detected by which manifest is present, never branched on by name. Verification scenarios
are _typed_ (`db` / `http` / `cli` / `console` / `test`) — an agnostic taxonomy; the project
resolves each type to a concrete command. With no declared commands a skill auto-detects and states
its assumption, asking when ambiguous — it never guesses silently. Every command is grounded in
something that exists in the repo (a route, a schema column, a file opened by Read), so nothing is
fabricated. Stack-specific examples live in `references/`, marked as examples, never as skill logic.

## Thin harness, fat skills

A skill's weight tracks the complexity of its procedure, not a fixed line budget. The body holds the
process and its guards; bulky detail — templates, scenario taxonomies, per-stack examples — lives in
`references/` and loads on demand. Skills come in three weights: trigger-only,
procedural-with-references, and procedural-standalone. The harness stays thin; the intelligence
lives in the markdown, where every model upgrade improves it for free.

## Composable, not chained

Skills stay separate — different axes, different inputs, different guards (a multi-axis diff review
is not the same job as checking a change against the repo's existing patterns). They connect through
three light layers, none of them a forced sequence:

1. **Shared artifacts** in `.ai/verify/<branch-slug>/` — a skill reads its neighbors' outputs when
   they exist (verify reads explain's scenarios; risk reads review and conform). The strongest link,
   because it is deterministic and survives `/clear`.
2. **A "Next:" pointer** at the end of each skill body, plus optional in-body delegation.
3. **A thin router** — the README task-router table.

The catalog is also self-contained: it never _depends_ on external skills (they might change or be
absent). Composition with outside tools is optional, never required — which is why a full review
skill ships here even though other reviewers exist.

## Explicit-only skills

`dw-handoff`, `dw-prune`, and `dw-sync` are invoked by name and never auto-trigger — they compact or
mutate state, or act on an explicit drift signal, so the model should not reach for them unbidden.
Everything else can be model-invoked when the task fits.
