---
name: dw-tickets
description: >-
  Break a run's ready `SPEC.md` into independently takeable tickets under
  `.ai/runs/<id>/tickets/` — tracer-bullet vertical slices, each declaring the tickets that block
  it, each sized for one fresh context window. Reach for it instead of `dw-plan` when a spec is too
  big for one `PLAN.md`: a plan is one sequential spine, tickets are a dependency graph with a
  frontier many sessions can pull from. Presents the breakdown and its edges for approval before
  writing; `take <NN>` then promotes a ticket into its own run so `dw-plan` → `dw-build` runs on it
  unchanged. Use when a ready spec is too large to plan in one go, or someone says "break this into
  tickets", "split the spec into subtasks", "what can I pick up next", or invokes "dw-tickets".
argument-hint: "empty = decompose the active run's spec; 'take <NN>'; 'status'; or a path to a SPEC.md"
---

# dw-tickets — turn a big spec into a dependency graph of takeable tickets

`dw-plan` writes one `PLAN.md`: a sequential spine, built row by row in one session.
That shape breaks down once a spec is large — the plan outgrows a context window, the
single not-done row serialises work that was never sequential, and a spec whose real
structure is "these three are blocked on another team, those two are independent
cleanups" can't be expressed as a list at all.

`dw-tickets` keeps the same decomposition discipline and changes the topology to a
graph. Each ticket is still a tracer-bullet vertical slice with observable acceptance,
but it also declares the tickets that block it — so what you read off the artifact is a
**frontier** (everything takeable right now) rather than a next row. It sits _above_ the
loop rather than replacing it: taking a ticket promotes it into its own run, and from
there `dw-plan` / `dw-build` / `dw-resume` work exactly as they always do.

Adapted from Matt Pocock's `to-tickets`, with one deliberate divergence: ticket bodies
**do** carry verified file anchors (see [Anchors](#anchors)), because every `dw-*` skill
grounds its output in real, confirmed referents.

## What it reads and writes

- **Reads:** the active run's `SPEC.md` (branch-matched, see below) and the codebase,
  **read-only** — you ground the tickets in real files but change none.
- **Writes:** `.ai/runs/<id>/tickets/NN-slug.md`, one file per ticket, plus
  `.ai/runs/<id>/tickets/INDEX.md` — once, after the gate.
- **In `take` mode:** additionally a new `.ai/runs/<new-id>/SPEC.md` for the taken
  ticket, created by the shared `new-run.sh`. Never code.

`.ai/` is tracked in git.

## When to use this instead of `dw-plan`

| Signal                                                | Reach for                                                  |
| ----------------------------------------------------- | ---------------------------------------------------------- |
| Spec fits one session; one obvious order              | `dw-plan`                                                  |
| Spec spans weeks, or has genuinely parallel tracks    | `dw-tickets`                                               |
| Some work is blocked on a human answer / another team | `dw-tickets` (encode it as ticket 01 that blocks the rest) |
| You want a status table to build down                 | `dw-plan`                                                  |
| You want a frontier to pull from                      | `dw-tickets`                                               |

The two compose: `dw-tickets` produces the graph, and each ticket taken from it gets its
own `PLAN.md` from `dw-plan`.

## Workflow

### 1. Pick the mode (`$ARGUMENTS`)

- **empty** → decompose the active run's spec. Steps 2–8.
- **a path to a `SPEC.md`** → decompose that spec instead of branch-matching. Skip step 2.
- **`take <NN>`** → promote ticket `NN` into its own run. Jump to step 9.
- **`status`** → read-only: print the graph, what is `done`, and the current frontier
  (every ticket whose blockers are all `done`). Write nothing. Stop.

### 2. Find the run (branch-matched, no index)

Get the current branch: `git rev-parse --abbrev-ref HEAD`. Glob `.ai/runs/*/` and read
each run's frontmatter `branch:` (from `SPEC.md`) — the same branch match `dw-resume`
and `dw-handoff` use. Resolve in order and **stop at the first that applies**:

1. **No `.ai/runs/` directory, or no run for this branch** → nothing to decompose. Point
   to `dw-spec` to write a spec first. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every run
   with its recorded `branch:`, ask which to decompose. Stop.
3. **Exactly one run matches the branch** → use it.
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the others so
   nothing is hidden. (Same-date tie → list both, ask.)

Never silently guess which run to decompose — if it's ambiguous, name the candidates and
ask.

### 3. Read the spec — decompose only when it is `ready`

Read the matched run's `SPEC.md` frontmatter `status`:

- **`ready`** → proceed.
- **`draft` or `open-questions`** → the scope is still moving, and decomposing it now
  bakes a moving target into a graph that later tickets point at. Finish `dw-spec` first
  (answer its Open Questions), then come back. Stop.
- **No `SPEC.md`** in the run → point to `dw-spec`. Stop.

If `tickets/` **already exists and is non-empty**, do not overwrite it. Ticket numbers
are referenced by `blocked_by` edges and by any run already taken from them, so
regenerating would orphan those references. Report what exists, print the frontier as in
`status` mode, and stop.

### 4. Ground the decomposition in the code (read-only)

Before slicing, read the repo so every ticket rests on something real — the same
anti-hallucination discipline `dw-plan` and `dw-review` use:

- Open the sibling files, modules, and patterns each ticket will follow, and note them by
  path. Confirm each with `Read`/`grep` — never reference a file, module, or command you
  haven't verified exists.
- Find the project's verify commands (each ticket's acceptance ends with one). Read them
  **from the project**, never hardcode: first a declared block (`## Commands` /
  `## Project specifics` in `CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` — test / lint /
  typecheck / run), then manifests (`package.json` scripts, `Makefile`, `Gemfile` +
  `bin/`, `pyproject.toml`…), then the code itself. If a command can't be found, state
  the assumption and ask rather than inventing one.
- Look for **prefactoring** opportunities — "make the change easy, then make the easy
  change". A prefactor becomes its own early ticket that blocks the others.

### 5. Draft tracer-bullet slices

<vertical-slice-rules>

- Each slice cuts a narrow but **complete** path through every layer it needs (schema,
  server, UI, tests) — vertical, never a horizontal slice of one layer.
- A completed slice is **demoable or verifiable on its own**.
- Each slice fits in **one fresh context window** — takeable with no prior conversation.
- Prefactors come first.

</vertical-slice-rules>

Give every ticket its **blocking edges**: the tickets that must complete before it can
start. A ticket with no blockers can start immediately. Keep edges minimal — an edge that
isn't a real gate turns the graph back into a queue.

Number tickets from `01` in dependency order, blockers first. Numbers are **immutable**
once written, because `blocked_by` edges and taken runs point at them.

**Wide refactors are the exception to vertical slicing.** A wide refactor is one
mechanical change — rename a column, retype a shared symbol — whose blast radius fans
across the codebase, so a single edit breaks thousands of call sites and no vertical
slice can land green. Sequence it as **expand–contract** instead:

1. **Expand** — add the new form beside the old so nothing breaks. One ticket.
2. **Migrate** — move call sites in batches sized by blast radius (per package, per
   directory), each batch its own ticket blocked by the expand. CI stays green batch by
   batch because the old form still exists.
3. **Contract** — delete the old form once no caller remains, blocked by every migrate
   batch.

If even the batches can't stay green alone, keep the sequence but let them share an
integration branch, and add a final integrate-and-verify ticket that every batch blocks —
green is promised only there. Say so in the tickets rather than letting a reviewer
discover it.

### 6. Present the breakdown and wait — HARD STOP

Show a numbered list. For each ticket: **title**, **blocked by**, and **what it
delivers** — the end-to-end behaviour it makes work. Then ask:

- Does the granularity feel right — too coarse, too fine?
- Are the blocking edges real gates, or did I over-serialise it?
- Should any tickets merge or split?

**Write nothing yet.** This gate mirrors `dw-spec`'s and `dw-plan`'s: a wrong
decomposition is cheap to fix as a list and expensive once its numbers are referenced by
edges and by taken runs. Iterate until the user approves explicitly.

### 7. Write the tickets

Write one file per ticket — `.ai/runs/<id>/tickets/NN-slug.md`, numbered in dependency
order — plus `INDEX.md`. One ticket per file, **never** a single combined file. Before
finishing, verify every `blocked_by` / `blocks` edge points at a ticket that exists and
that each edge is recorded on both ends.

### 8. Stop

> **Next:** `dw-tickets status` for the frontier · `dw-tickets take <NN>` to promote a
> ticket into its own run, then `dw-plan` → `dw-build` inside it.

### 9. `take <NN>` — promote a ticket into its own run

1. Read `tickets/NN-*.md`. If any ticket in its `blocked_by` is not `done`, name them and
   stop.
2. Create the branch per the project's `## Git conventions` — read them, never assume a
   naming scheme. If none are declared, ask.
3. Create the run with the shared spine script rather than by hand, so the frontmatter is
   machine-exact and the artifact validator accepts it:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/new-run.sh" "<ticket-or-none>" "<short desc>"
   ```

   Then fill that run's `SPEC.md` body from the ticket: what to build, acceptance
   criteria, anchors — plus `parent_run:` and `parent_ticket:` keys pointing back. Leave
   the spine keys the script wrote (`run` / `ticket` / `status` / `created` / `branch`)
   alone. This is what keeps the rest of the loop untouched: `dw-plan` sees an ordinary
   ready spec.

4. Flip the parent ticket's frontmatter `status:` to `doing` and refresh `INDEX.md`.
5. Stop with:

> **Next:** `dw-plan` in the new run.

Never write code in `take` mode.

## The ticket shape

Write exactly these two shapes.

```markdown
---
ticket: "03"
run: YYYYMMDD-parent-run-slug
title: [short descriptive name]
status: ready # ready | doing | done | blocked
blocked_by: ["01", "02"] # [] when it can start immediately
blocks: ["04", "05"]
---

# 03 — [title]

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective — not a
layer-by-layer implementation list.

## Acceptance criteria

- [ ] [observable outcome]
- [ ] [the project's verify command passes — the real one, read from the project]

## Blocked by

- `01 — [title]` — [why it is a real gate], or "None — can start immediately".

## Anchors

- `path/to/file.rb:42` — [what it is and why this ticket cares]
```

```markdown
---
run: YYYYMMDD-parent-run-slug
spec: ../SPEC.md
tickets: 11
---

# Tickets — [spec title]

Frontier = every ticket whose blockers are all `done`. Numbers are immutable.

| #   | Title   | Status | Blocked by | Blocks |
| --- | ------- | ------ | ---------- | ------ |
| 01  | [title] | ready  | —          | 03     |

## Graph

[blocks as an indented tree or arrow list — enough to see the critical path]

## Frontier now

- `01`, `02` — takeable immediately.
```

## Anchors

The original `to-tickets` bans file paths from ticket bodies because they go stale. Here
they're kept, in a dedicated `## Anchors` section, because a ticket must be executable in
a fresh session with no prior conversation — and a verified path is the cheapest way to
hand over that grounding. The rules that keep them honest:

- Every anchor is **verified** with `Read`/`grep` at decomposition time. Never cite a path
  you haven't opened.
- Anchors are **orientation, not instructions** — "this is the pattern to follow", never a
  line-by-line edit script. The implementation decision stays with the session that takes
  the ticket.
- Keep them few. A ticket needing a dozen anchors is too big.
- Code snippets only when they encode a decision more precisely than prose can — a state
  machine, a schema, a type shape. Trim to the decision-rich part.

## Guardrails

- **Read-only until the gate.** You read the spec and the code to decompose; no file is
  written before explicit approval.
- **Never overwrite an existing `tickets/`.** Numbers are referenced by edges and by taken
  runs; regenerating orphans them. Surface it, don't clobber.
- **Decompose only a `ready` spec.** Draft or open-questions goes back to `dw-spec`.
- **Numbers are immutable.** Add `12`, `13`; never renumber `03`.
- **No code, ever** — not when decomposing, not in `take` mode. Building is `dw-build`'s
  job.
- **Commands come from the project**, never from this skill.
- **Every acceptance criterion is observable.** "Works correctly" is not a criterion; "the
  suite is green and the row appears in the audit log" is.
- **Edges are reciprocal and resolvable.** Every `blocked_by` has a matching `blocks` on
  the other ticket, and every referenced number exists.
- **Never silently guess.** Ambiguous run, missing spec, unfound command, unclear edge —
  name it and ask.
