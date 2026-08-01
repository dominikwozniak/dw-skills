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
| The work is too big for one plan          | A slice graph with a frontier, each slice its own run         |
| One skill grows into a do-everything blob | One skill, one job — they compose through `.ai/`, not chains  |
| The process outweighs the change          | Two lanes — team ceremony, or one file and one pass           |

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

Tier 1 is populated, not hoped for: `dw-bootstrap` seeds `## Commands` in
**tracked** `CLAUDE.md` from the commands it actually found in the manifests. Tracked matters — a copy
that lives only in the gitignored `CLAUDE.local.md` is invisible on a fresh clone and to any agent that
reads `AGENTS.md`. That file keeps its own copy anyway, because the lint and typecheck hooks grep it for
those names, so the two must be updated together.

Being gitignored has one more consequence, and it is the reason the `link-local-memory` hook exists: a
`git worktree` checkout receives only **tracked** files, so `CLAUDE.local.md` is simply absent there.
`.claude/settings.json`, `.claude/hooks/` and `.ai/` are tracked and do materialise, but without that
file `dw-git` loses the repo's `## Git conventions` — commit format, trailer policy, the signing rule —
and falls back to generic defaults. The visible symptom is a worktree commit carrying a trailer the main
tree forbids. The hook closes it by symlinking the main tree's copy in at `SessionStart`, detecting the
worktree via `--git-dir` vs `--git-common-dir` (a path compare would misfire: in the main tree
`--git-common-dir` returns a relative `.git`). It also prints a pointer, because nothing guarantees the
symlink lands before memory files are read — without that line the conventions would only reach context
in the _next_ session.

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

The same budget applies to a skill's `description`. Every installed skill's description sits in the
context window of every session, whether or not the skill fires — so it carries routing signal only:
what the skill does, how it differs from its nearest sibling, and the phrases that should trigger it.
Procedure detail belongs in the body, which is paid for once, on invoke.

## The symlink canon — one file, many plugins

**A skill or a shipped script exists once, and plugins reach it through git-tracked symlinks.** The
canon is `skills/<name>/` and `scripts/runtime/<script>.sh`; `plugins/<plugin>/skills/<name>` and
`plugins/<plugin>/scripts/<script>.sh` are mode-120000 symlinks back to it.

This works because `claude plugin install` **dereferences** symlinks — each plugin gets its own real
copy in the plugin cache (verified: the installed cache contains 0 symlinks). So a skill body invokes
a shipped script through the unchanged `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh` and the path
resolves to a real file.

Two consequences:

- **One canonical script can serve several plugins** with no duplication — `slugify.sh` is symlinked
  into both `dw-planning` and `dw-quality`. A script used by only _one_ skill needs no canon: it
  stays bundled in `skills/<name>/scripts/` and is invoked via `<this-skill-dir>/…`, as `dw-doctor`
  does.
- **`templates/` is a canon for the same reason.** `dw-bootstrap` copies the hooks and
  `settings.json` into a target project, so the payload lives once and is read as
  `${CLAUDE_PLUGIN_ROOT}/templates/…`. `scripts/tests/hooks-in-sync.test.sh` pins this repo's own
  `.claude/hooks/` to that canon, so the hooks you run are the hooks you ship. The same hooks are
  **vendored** by `dw-solo-skills`; that copy is byte-identical today and no test can see across the
  repo boundary, so a fix here has to be applied there too.

The cost is one rule, and it is absolute: **never edit through a `plugins/…` path** — you would be
editing the canon by accident on a dev checkout, and writing to a private copy after install.

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

## A spine or a graph — `dw-plan` vs `dw-split`

**One artifact shape doesn't fit every scope, so there are two.** `PLAN.md` is a **spine**: an
ordered status table whose first not-`done` row is the resume point. That shape is what makes
`dw-resume` deterministic and `dw-build` boring, and it's right for almost everything — one session,
one order, one place to pick up.

It has a size limit. Past a certain scope the plan outgrows a context window, the single resume point
serialises work that was never sequential, and a spec whose real structure is "these three are
blocked on another team, those two are independent cleanups" can't be expressed as a list.

`dw-split` keeps the decomposition discipline and changes the topology to a **graph**. Each slice
is still a tracer-bullet vertical slice with observable acceptance, but it also declares the slices
that block it — so the artifact yields a _frontier_ (everything takeable now) instead of a next row.
It sits above the loop rather than replacing it: `take <NN>` promotes a slice into its own run via
the same `new-run.sh` spine `dw-spec` uses, so `dw-plan` → `dw-build` → `dw-resume` run unchanged.

**A slice is not a ticket, and the words are kept apart.** A _ticket_ is the external tracker's unit —
the Jira / Linear key that lands in a run's `SPEC.md` as `ticket: ABC-123` and in the commit subject
as `[ABC-123]`. A _slice_ is internal to one run, numbered `NN`, and never leaves the repo. One
external ticket → one spec → many slices, and a promoted slice inherits the parent's `ticket:` while
recording `parent_slice:` beside it. Overloading one word across both would have made `ticket:` in the
frontmatter ambiguous, which is why this skill is `dw-split` and not `dw-tickets`.

Three consequences worth naming:

- **Numbers are immutable**, for the same reason committed step ids are — edges and taken runs point
  at them, so renumbering orphans history.
- **One run, one topology.** A run holding both a `PLAN.md` and a `slices/` has two resume points,
  which is none, so `validate-ai-artifacts.sh` fails it. The two compose the other way: each slice
  taken from the graph gets its own run and its own plan.
- **Slices carry verified file anchors.** A slice has to be executable in a fresh session with no
  prior conversation, so it needs the grounding a `PLAN.md` inherits from the run around it. Anchors
  are orientation, never an edit script — and the session that _takes_ a slice re-verifies them,
  because verification at write time doesn't survive two weeks of other people's commits.

The graph's derived state gets the same treatment as a plan's: `plan-status.sh` owns "the resume point
is the first not-`done` row", and `slice-status.sh` owns the frontier plus the invariants a list
doesn't have — every edge recorded on both ends, every number resolvable. `dw-split` and `dw-resume`
both call it rather than re-deriving in-context, so a one-sided edge fails loudly instead of silently
hiding the dependency the graph existed to expose.

## Two lanes, two repos

**The amount of process a change deserves depends on who reads the artifacts, so there are two
lanes.** This repo is the **team lane** — it assumes other people read the artifacts and assume
nothing. The thin lane lives in its own marketplace,
[`dw-solo-skills`](https://github.com/dominikwozniak/dw-solo-skills), for repos only you read.

|                    | This repo (`dw-planning` + `dw-quality`)            | `dw-solo-skills`                    |
| ------------------ | --------------------------------------------------- | ----------------------------------- |
| Loop               | `dw-spec → dw-plan → dw-build`                      | `dw-shape → dw-next → dw-ship`      |
| Planning artifacts | `SPEC.md` + `PLAN.md` + `NOTES.md` (+ `slices/`)    | one `CHANGE.md`                     |
| Quality            | 5 auditors + `dw-fix`, up to 7 artifacts            | one `dw-land` pass, no artifact     |
| Resume point       | `dw-resume` → first not-`done` row, or the frontier | `dw-next` bare → first unticked box |
| Scaffolder         | `dw-bootstrap`                                      | `dw-init`                           |
| Assumes            | other people read this, and assume nothing          | you are the only reader             |

**Install one lane per repo, not both.** Two lanes in one project means two skills competing for
"start a feature", and no description wording fixes that reliably. Claude Code scopes plugins per
project, which is the right place to make the choice once — `dw-doctor` reports when it finds
`.ai/work/` in a repo running this lane.

### Why they're separate repos

They shared this repo until the `templates/` canon became the problem. The payload here is shaped for
`dw-bootstrap`, and the thin lane paid for it at runtime: its scaffolder had to replace a whole
`## Workflow` section in `CLAUDE.local.md` after copying it, skip `templates/ai-README.md` entirely
(it documents `runs/`/`verify/`/`handoffs/`, directories that lane never creates) and hand-write a
replacement inline, and append a gitignore block whose markers read `dw-bootstrap managed block`.
Three work-arounds-in-prose that a lane-owned `templates/` deletes outright.

The cost, recorded rather than discovered later: `templates/hooks/*.sh` and
`scripts/runtime/slugify.sh` are **vendored byte-identical copies** in the other repo. A fix here does
not reach it, and nothing across the boundary can detect drift — `hooks-in-sync.test.sh` only pins
this repo's `.claude/hooks/` to its own canon. `dw-git`, `dw-doctor` and `dw-setup-precommit` exist as
deliberately simplified forks there and are expected to diverge.

Two things the thin lane drops, and why that's safe there:

- **The auditor/writer separation.** `dw-review` and friends never edit code because an auditor that
  can also patch under-reports what it couldn't fix. With one reader, you read every finding before
  anything happens, so the honesty is enforced by you instead — a single gated pass reports first and
  mutates only after explicit approval, with the gate doing the work the skill boundary did.
- **The validated status table.** `PLAN.md`'s SHA column and immutable step ids exist so a second
  reader can trust the record. A checklist has no invariants that can break silently, which is why
  `validate-ai-artifacts.sh` deliberately never sweeps `.ai/work/` — a sweep kept after the split, so
  that a repo with both lanes installed still doesn't get its `CHANGE.md` files failed here.

The idea this repo takes _from_ that lane is `.ai/BACKLOG.md`: a flat list of follow-ups. It stays
there and not here because a shared repo already has the two things that make it redundant — a
tracker, and a `NOTES.md` that outlives the run.

## Explicit-only skills

`dw-bootstrap`, `dw-handoff`, `dw-prune`, `dw-split`, `dw-sync`, and `dw-setup-precommit`
are invoked by name and never auto-trigger — they scaffold a repo, install shared tooling, compact or mutate state,
or act on an explicit drift signal, so the model shouldn't reach for them unbidden. `dw-split` is here
for a different reason: it picks the artifact _topology_ for a spec, and that pick is effectively
irreversible (numbers are immutable, `slices/` is never overwritten, and a graph excludes a plan). A
model that reaches for a graph where you wanted a spine costs you the run, so the choice stays with
you. Everything else can be model-invoked when the task fits.

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
