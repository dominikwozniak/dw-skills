---
name: dw-split
description: >-
  Split a run's ready `SPEC.md` into a dependency graph of independently takeable slices under
  `.ai/runs/<id>/slices/`, each sized for one fresh context window. Reach for it instead of `dw-
  plan` when a spec is too big for one `PLAN.md`: a plan is one sequential spine, slices are a
  graph with a frontier many sessions can pull from. Explicit-invoke only. Use when a ready spec
  is too large to plan in one go, or someone says "split the spec", "break this into slices",
  "what can I pick up next".
disable-model-invocation: true
argument-hint: "empty = split the active run's spec; 'take <NN>'; 'status'; or a path to a SPEC.md"
---

# dw-split — turn a big spec into a dependency graph of takeable slices

`dw-plan` writes one `PLAN.md`: a sequential spine, built row by row in one session.
That shape breaks down once a spec is large — the plan outgrows a context window, the
single not-done row serialises work that was never sequential, and a spec whose real
structure is "these three are blocked on another team, those two are independent
cleanups" can't be expressed as a list at all.

`dw-split` keeps the same decomposition discipline and changes the topology to a
graph. Each slice is still a tracer-bullet vertical slice with observable acceptance,
but it also declares the slices that block it — so what you read off the artifact is a
**frontier** (everything takeable right now) rather than a next row. It sits _above_ the
loop rather than replacing it: taking a slice promotes it into its own run, and from
there `dw-plan` / `dw-build` / `dw-resume` work exactly as they always do.

Adapted from Matt Pocock's `to-tickets`, with one deliberate divergence: slice bodies
**do** carry verified file anchors (see [Anchors](#anchors)), because every `dw-*` skill
grounds its output in real, confirmed referents.

## A slice is not a ticket

Two different things, and this repo keeps the words apart:

- An **external ticket** is the tracker's unit — the Jira / Linear key that lands in a
  run's `SPEC.md` frontmatter as `ticket: ABC-123` and in the commit subject as
  `[ABC-123]`. It comes from outside; nothing here creates one.
- A **slice** is an _internal_ unit this skill carves out of one spec, numbered `NN`
  inside that run. It never leaves the repo.

So the normal shape is: one external ticket → one `SPEC.md` → many slices. A slice
promoted by `take` inherits the parent's `ticket:` and records `parent_slice:` alongside
it — same external ticket, one internal slice of it.

## What it reads and writes

- **Reads:** the active run's `SPEC.md` (branch-matched, see below) and the codebase,
  **read-only** — you ground the slices in real files but change none.
- **Writes:** `.ai/runs/<id>/slices/NN-slug.md`, one file per slice, plus
  `.ai/runs/<id>/slices/INDEX.md` — once, after the gate.
- **In `take` mode:** additionally a new `.ai/runs/<new-id>/SPEC.md` for the taken
  slice, created by the shared `new-run.sh`. Never code.

`.ai/` is tracked in git.

## When to use this instead of `dw-plan`

| Signal                                                | Reach for                                               |
| ----------------------------------------------------- | ------------------------------------------------------- |
| Spec fits one session; one obvious order              | `dw-plan`                                               |
| Spec spans weeks, or has genuinely parallel tracks    | `dw-split`                                              |
| Some work is blocked on a human answer / another team | `dw-split` (encode it as slice 01 that blocks the rest) |
| You want a status table to build down                 | `dw-plan`                                               |
| You want a frontier to pull from                      | `dw-split`                                              |

One run gets **one** topology, never both — a run holding a `PLAN.md` and a `slices/`
has two resume points, which is none. The two compose the other way: `dw-split` produces
the graph, and each slice taken from it gets its own run with its own `PLAN.md` from
`dw-plan`. The artifact validator enforces the exclusion.

## Workflow

### 1. Pick the mode (`$ARGUMENTS`)

- **empty** → split the active run's spec. Steps 2–8.
- **a path to a `SPEC.md`** → split that spec instead of branch-matching. Skip step 2.
- **`take <NN>`** → promote slice `NN` into its own run. Jump to step 9.
- **`status`** → read-only: print the graph, what is `done`, and the current frontier.
  Get the frontier from the script, never by eye:

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice-status.sh" --frontier .ai/runs/<id>/slices
  ```

  Write nothing. Stop.

### 2. Find the run (branch-matched, no index)

Get the current branch: `git rev-parse --abbrev-ref HEAD`. Glob `.ai/runs/*/` and read
each run's frontmatter `branch:` (from `SPEC.md`) — the same branch match `dw-resume`
and `dw-handoff` use. Resolve in order and **stop at the first that applies**:

1. **No `.ai/runs/` directory, or no run for this branch** → nothing to split. Point
   to `dw-spec` to write a spec first. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every run
   with its recorded `branch:`, ask which to split. Stop.
3. **Exactly one run matches the branch** → use it.
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the others so
   nothing is hidden. (Same-date tie → list both, ask.)

Never silently guess which run to split — if it's ambiguous, name the candidates and
ask.

### 3. Read the spec — split only when it is `ready`

Read the matched run's `SPEC.md` frontmatter `status`:

- **`ready`** → proceed.
- **`draft` or `open-questions`** → the scope is still moving, and splitting it now
  bakes a moving target into a graph that later slices point at. Finish `dw-spec` first
  (answer its Open Questions), then come back. Stop.
- **No `SPEC.md`** in the run → point to `dw-spec`. Stop.

If the run already has a **`PLAN.md`**, it is already a spine — say so and stop. Turning
a plan in flight into a graph is not this skill's job; finish it, or reconcile it with
`dw-sync`.

If `slices/` **already exists and is non-empty**, do not overwrite it. Slice numbers
are referenced by `blocked_by` edges and by any run already taken from them, so
regenerating would orphan those references. Report what exists, print the frontier as in
`status` mode, and stop.

### 4. Ground the decomposition in the code (read-only)

Before slicing, read the repo so every slice rests on something real — the same
anti-hallucination discipline `dw-plan` and `dw-review` use:

- Open the sibling files, modules, and patterns each slice will follow, and note them by
  path. Confirm each with `Read`/`grep` — never reference a file, module, or command you
  haven't verified exists.
- Find the project's verify commands (each slice's acceptance ends with one). Read them
  **from the project**, never hardcode: first a declared block (`## Commands` /
  `## Project specifics` in `CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` — test / lint /
  typecheck / run), then manifests (`package.json` scripts, `Makefile`, `Gemfile` +
  `bin/`, `pyproject.toml`…), then the code itself. If a command can't be found, state
  the assumption and ask rather than inventing one.
- Look for **prefactoring** opportunities — "make the change easy, then make the easy
  change". A prefactor becomes its own early slice that blocks the others.

### 5. Draft tracer-bullet slices

<vertical-slice-rules>

- Each slice cuts a narrow but **complete** path through every layer it needs (schema,
  server, UI, tests) — vertical, never a horizontal slice of one layer.
- A completed slice is **demoable or verifiable on its own**.
- Each slice fits in **one fresh context window** — takeable with no prior conversation.
- Prefactors come first.

</vertical-slice-rules>

Give every slice its **blocking edges**: the slices that must complete before it can
start. A slice with no blockers can start immediately. Keep edges minimal — an edge that
isn't a real gate turns the graph back into a queue.

Number slices from `01` in dependency order, blockers first. Numbers are **immutable**
once written, because `blocked_by` edges and taken runs point at them.

**Wide refactors are the exception to vertical slicing.** A wide refactor is one
mechanical change — rename a column, retype a shared symbol — whose blast radius fans
across the codebase, so a single edit breaks thousands of call sites and no vertical
slice can land green. Sequence it as **expand–contract** instead:

1. **Expand** — add the new form beside the old so nothing breaks. One slice.
2. **Migrate** — move call sites in batches sized by blast radius (per package, per
   directory), each batch its own slice blocked by the expand. CI stays green batch by
   batch because the old form still exists.
3. **Contract** — delete the old form once no caller remains, blocked by every migrate
   batch.

If even the batches can't stay green alone, keep the sequence but let them share an
integration branch, and add a final integrate-and-verify slice that every batch blocks —
green is promised only there. Say so in the slices rather than letting a reviewer
discover it.

### 6. Present the breakdown and wait — HARD STOP

Show a numbered list. For each slice: **title**, **blocked by**, and **what it
delivers** — the end-to-end behaviour it makes work. Then ask:

- Does the granularity feel right — too coarse, too fine?
- Are the blocking edges real gates, or did I over-serialise it?
- Should any slices merge or split?

**Write nothing yet.** This gate mirrors `dw-spec`'s and `dw-plan`'s: a wrong
decomposition is cheap to fix as a list and expensive once its numbers are referenced by
edges and by taken runs. Iterate until the user approves explicitly.

### 7. Write the slices

Write one file per slice — `.ai/runs/<id>/slices/NN-slug.md`, numbered in dependency
order — plus `INDEX.md`. One slice per file, **never** a single combined file. Then let
the script check the graph rather than re-reading the edges by eye:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice-status.sh" --check .ai/runs/<id>/slices
```

It fails on a one-sided edge, an unresolvable number, a bad status, a duplicate id, or an
`INDEX.md` count that disagrees with the files. Fix what it reports before stopping.

### 8. Stop

> **Next:** `dw-split status` for the frontier · `dw-split take <NN>` to promote a
> slice into its own run, then `dw-plan` → `dw-build` inside it.

### 9. `take <NN>` — promote a slice into its own run

1. Read `slices/NN-*.md`. If any slice in its `blocked_by` is not `done`, name them and
   stop.
2. **Re-verify the slice's anchors** before handing it on: open each `## Anchors` path. If
   one no longer resolves, the code moved under the slice — say which anchor moved and
   ask, rather than silently re-deriving what the slice meant.
3. Create the branch per the project's `## Git conventions` — read them, never assume a
   naming scheme. If none are declared, ask.
4. Create the run with the shared spine script rather than by hand, so the frontmatter is
   machine-exact and the artifact validator accepts it:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/new-run.sh" "<ticket-or-none>" "<short desc>" ready
   ```

   The third argument is why `dw-plan` can pick this up immediately: the slice already
   passed the gate in step 6, so its spec is born `ready` rather than `draft`. Pass the
   **parent's** external `ticket:` value (or `none`) — a slice is not a ticket.

   Then fill that run's `SPEC.md` body from the slice: what to build, acceptance
   criteria, anchors — plus `parent_run:` and `parent_slice:` keys pointing back. Leave
   the spine keys the script wrote (`run` / `ticket` / `status` / `created` / `branch`)
   alone. This is what keeps the rest of the loop untouched: `dw-plan` sees an ordinary
   ready spec.

5. Flip the parent slice's frontmatter `status:` to `doing` and refresh `INDEX.md`.
6. Stop with:

> **Next:** `dw-plan` in the new run.

Never write code in `take` mode.

## The slice shape

Write exactly these two shapes.

```markdown
---
slice: "03"
run: YYYYMMDD-parent-run-slug
title: [short descriptive name]
status: ready # ready | doing | done | blocked
blocked_by: ["01", "02"] # [] when it can start immediately
blocks: ["04", "05"]
---

# 03 — [title]

## What to build

The end-to-end behaviour this slice makes work, from the user's perspective — not a
layer-by-layer implementation list.

## Acceptance criteria

- [ ] [observable outcome]
- [ ] [the project's verify command passes — the real one, read from the project]

## Blocked by

- `01 — [title]` — [why it is a real gate], or "None — can start immediately".

## Anchors

- `path/to/file.rb:42` — [what it is and why this slice cares]
```

```markdown
---
run: YYYYMMDD-parent-run-slug
spec: ../SPEC.md
slices: 11
---

# Slices — [spec title]

Frontier = every slice whose blockers are all `done`. Numbers are immutable.

| #   | Title   | Status | Blocked by | Blocks |
| --- | ------- | ------ | ---------- | ------ |
| 01  | [title] | ready  | —          | 03     |

## Graph

[blocks as an indented tree or arrow list — enough to see the critical path]

## Frontier now

- `01`, `02` — takeable immediately.
```

`slice-status.sh --check` reads both shapes, so the frontmatter keys and the `INDEX.md`
count are not decorative — get them exactly right.

## Anchors

The original `to-tickets` bans file paths from ticket bodies because they go stale. Here
they're kept, in a dedicated `## Anchors` section, because a slice must be executable in
a fresh session with no prior conversation — and a verified path is the cheapest way to
hand over that grounding. The rules that keep them honest:

- Every anchor is **verified** with `Read`/`grep` at decomposition time. Never cite a path
  you haven't opened.
- **Re-verified when the slice is taken** (step 9.2). Verification at write time doesn't
  survive two weeks of other people's commits, so the taking session checks before
  trusting — and asks when an anchor has moved.
- Anchors are **orientation, not instructions** — "this is the pattern to follow", never a
  line-by-line edit script. The implementation decision stays with the session that takes
  the slice.
- Keep them few. A slice needing a dozen anchors is too big.
- Code snippets only when they encode a decision more precisely than prose can — a state
  machine, a schema, a type shape. Trim to the decision-rich part.

## Guardrails

- **Read-only until the gate.** You read the spec and the code to split; no file is
  written before explicit approval.
- **One run, one topology.** Never write `slices/` into a run that has a `PLAN.md`, and
  never plan a run that has `slices/` — two resume points is no resume point. The artifact
  validator fails a run holding both.
- **Never overwrite an existing `slices/`.** Numbers are referenced by edges and by taken
  runs; regenerating orphans them. Surface it, don't clobber.
- **Split only a `ready` spec.** Draft or open-questions goes back to `dw-spec`.
- **Numbers are immutable.** Add `12`, `13`; never renumber `03`.
- **No code, ever** — not when splitting, not in `take` mode. Building is `dw-build`'s
  job.
- **Commands come from the project**, never from this skill.
- **Every acceptance criterion is observable.** "Works correctly" is not a criterion; "the
  suite is green and the row appears in the audit log" is.
- **The graph is checked by the script**, not by eye — `slice-status.sh --check` after
  writing, `--frontier` whenever you report what's takeable.
- **Never silently guess.** Ambiguous run, missing spec, unfound command, unclear edge —
  name it and ask.
