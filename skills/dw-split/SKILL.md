---
name: dw-split
description: >-
  Split a run's ready `SPEC.md` into a dependency graph of independently takeable slices under
  `.ai/runs/<id>/slices/`, each sized for one fresh context window — a graph whose frontier many
  sessions can pull from, where a plan is one sequential spine. Explicit-invoke only. Use when a
  ready spec is too large to plan in one go, or someone says "split the spec", "break this into
  slices", "what can I pick up next". Prefer this over `dw-plan` when the spec has genuinely
  parallel tracks, or work blocked on another team.
argument-hint: "empty = split the active run's spec; 'take <NN>'; 'status'; or a path to a SPEC.md"
disable-model-invocation: true
---

# dw-split — turn a big spec into a dependency graph of takeable slices

`PLAN.md` is a spine — one order, one resume point — and past a certain scope it outgrows a
context window and serialises work that was never sequential. Same decomposition discipline
here, different topology: each slice declares what blocks it, so the artifact yields a
**frontier** (everything takeable now) instead of a next row. It sits _above_ the loop rather
than replacing it — `take <NN>` promotes a slice into its own run, where `dw-plan` /
`dw-build` / `dw-resume` work as they always do. Rationale:
[`DESIGN.md`](../../docs/DESIGN.md), "A spine or a graph".

## What it reads and writes

- **Reads:** the active run's `SPEC.md` (branch-matched) and the codebase, **read-only** —
  you ground the slices in real files but change none.
- **Writes:** `.ai/runs/<id>/slices/NN-slug.md`, one file per slice, plus
  `.ai/runs/<id>/slices/INDEX.md` — once, after the gate.
- **In `take` mode:** additionally a new `.ai/runs/<new-id>/SPEC.md` for the taken slice,
  created by the shared `new-run.sh`. Never code.

`.ai/` is tracked in git.

## Workflow

### 1. Pick the mode (`$ARGUMENTS`)

- **empty** → split the active run's spec. Steps 2–8.
- **a path to a `SPEC.md`** → split that spec instead of branch-matching. Skip step 2.
- **`take <NN>`** → promote slice `NN` into its own run. Jump to step 9.
- **`status`** → read-only: print the graph, what is `done`, and the current frontier. Get
  the frontier from the script, never by eye:

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice-status.sh" --frontier .ai/runs/<id>/slices
  ```

  Write nothing. Stop.

### 2. Find the run (branch-matched, no index)

Resolve the run with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/find-active-run.sh"` — it matches
the current git branch against each run's `SPEC.md` `branch:` field, prints the run directory
(on a multi-match, the most recently modified, and it says so on stderr), and exits non-zero
when none does. (`${CLAUDE_PLUGIN_ROOT}` is the install dir Claude Code substitutes; the
script ships with the plugin.) Then **stop at the first that applies**:

1. **No `.ai/runs/`, or no run for this branch** → nothing to split. Point to `dw-spec`. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every run with
   its recorded `branch:`, ask which to split. Stop.
3. **A run resolves** → use it; on a multi-match, name the one you're using and the ones
   you're not.

### 3. Read the spec — split only when it is `ready`

The matched run's `SPEC.md` frontmatter `status` must be **`ready`**. On `draft` or
`open-questions`, stop: the scope is still moving, and splitting now bakes a moving target
into a graph that later slices point at — finish `dw-spec` first. No `SPEC.md` at all → point
to `dw-spec`. Stop.

Then two topology checks, each a stop:

- Run already has a **`PLAN.md`** → it is already a spine. Finish it, or reconcile it with
  `dw-sync`; converting a plan in flight is not this skill's job.
- **`slices/` already exists** and is non-empty → never overwrite. Report what exists, print
  the frontier as in `status` mode.

### 4. Ground the decomposition in the code (read-only)

Read the repo first so every slice rests on something real — the same anti-hallucination
discipline `dw-plan` and `dw-review` use:

- Open the sibling files, modules, and patterns each slice will follow and note them by path.
  Confirm each with `Read`/`grep` — never reference a file, module, or command you haven't
  verified exists.
- Find the project's verify commands (each slice's acceptance ends with one) **from the
  project**, never hardcoded: a declared `## Commands` / `## Project specifics` block in
  `CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` first, then manifests (`package.json`,
  `Makefile`, `pyproject.toml`…), then the code. If one can't be found, say so and ask.
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

Number slices from `01` in dependency order, blockers first, and give each its **blocking
edges** — recorded on **both** ends (`blocked_by` on the blocked slice, `blocks` on the
blocker), because a one-sided edge silently hides the dependency the graph exists to expose.
Keep edges minimal; one that isn't a real gate turns the graph back into a queue.

**Wide refactors are the exception to vertical slicing.** When one mechanical change (rename a
column, retype a shared symbol) fans out so far that no vertical slice can land green, sequence
it as **expand–contract**: a slice adding the new form beside the old, one slice per migration
batch sized by blast radius (each blocked by the expand), a slice deleting the old form once no
caller remains (blocked by every batch). If even the batches can't be green alone, say so in
the slices, let them share an integration branch, and add a final integrate-and-verify slice
that every batch blocks — green is promised only there.

### 6. Present the breakdown and wait — HARD STOP

Show a numbered list. For each slice: **title**, **blocked by**, and **what it delivers** — the
end-to-end behaviour it makes work. Every acceptance criterion must be observable: "works
correctly" is not one, "the suite is green and the row appears in the audit log" is. Then ask
whether the granularity is right, whether the edges are real gates or over-serialised, and
whether any slices should merge or split.

**Write nothing yet**, and iterate until the user approves explicitly. A wrong decomposition is
cheap to fix as a list and expensive once its numbers are referenced by edges and taken runs.

### 7. Write the slices

Write one file per slice — `.ai/runs/<id>/slices/NN-slug.md`, in dependency order — plus
`INDEX.md`. One slice per file, **never** a single combined file. Then let the script check the
graph rather than re-reading the edges by eye:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice-status.sh" --check .ai/runs/<id>/slices
```

It fails on a one-sided edge, an unresolvable number, a bad status, a duplicate id, or an
`INDEX.md` count that disagrees with the files. Fix what it reports before stopping.

### 8. Stop

> **Next:** `dw-split status` for the frontier · `dw-split take <NN>` to promote a slice into
> its own run, then `dw-plan` → `dw-build` inside it.

### 9. `take <NN>` — promote a slice into its own run

1. Read `slices/NN-*.md`. If any slice in its `blocked_by` is not `done`, name them and stop.
2. **Re-verify the slice's anchors** before handing it on: open each `## Anchors` path. If one
   no longer resolves, the code moved under the slice — say which anchor moved and ask, rather
   than silently re-deriving what the slice meant.
3. Create the branch per the project's `## Git conventions` — read them, never assume a naming
   scheme. If none are declared, ask.
4. Create the run with the shared spine script, not by hand, so the frontmatter is
   machine-exact and the artifact validator accepts it:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/new-run.sh" "<ticket-or-none>" "<short desc>" ready
   ```

   The third argument is born `ready`, not `draft`, because the slice already passed the gate
   in step 6 — that's why `dw-plan` can pick it up immediately. Pass the **parent's** external
   `ticket:` value (or `none`): a slice is internal to one run and never leaves the repo, so it
   is not a ticket of its own.

   Then fill that run's `SPEC.md` body from the slice — what to build, acceptance criteria,
   anchors — plus `parent_run:` and `parent_slice:` pointing back. Leave the spine keys the
   script wrote (`run` / `ticket` / `status` / `created` / `branch`) alone, and `dw-plan` sees
   an ordinary ready spec.

5. In the parent slice, set `status: doing` **and** `taken_run: <new-run-id>`, then refresh
   `INDEX.md`. That back-pointer is what lets `dw-resume` name the in-flight child run instead
   of hunting for it.
6. Stop with:

> **Next:** `dw-plan` in the new run.

Never write code in `take` mode.

## The slice shape

`references/slice.md` and `references/INDEX.md` are the exact shapes to copy. `--check` reads
both, so the frontmatter keys and the `INDEX.md` `slices:` count are not decorative; only
`taken_run:` is optional, empty until `take` fills it.

## Anchors

A slice has to be executable in a fresh session with no prior conversation, and a verified path
is the cheapest way to hand over that grounding — so slice bodies carry file anchors. Keep them
honest: **verified at decomposition time** with `Read`/`grep` and kept few (a slice needing a
dozen anchors is too big); **re-verified when the slice is taken**, because write-time
verification doesn't survive two weeks of other people's commits; and **orientation, not
instructions** — the pattern to follow, never a line-by-line edit script. The implementation
decision belongs to the session that takes the slice.

## Guardrails

- **One run, one topology.** Never write `slices/` into a run with a `PLAN.md`, never plan a run
  with `slices/` — two resume points is no resume point, and the artifact validator fails a run
  holding both. They compose the other way: each slice taken gets its own run and its own plan.
- **Never overwrite an existing `slices/`.** Numbers are referenced by edges and by taken runs;
  regenerating orphans them. Surface it, don't clobber.
- **Numbers are immutable.** Add `12`, `13`; never renumber `03`.
- **No code, ever** — not when splitting, not in `take` mode. Building is `dw-build`'s job.
- **The graph is checked by the script**, not by eye — `--check` after writing, `--frontier`
  whenever you report what's takeable.

## References

- `references/slice.md` — the shape of one `NN-slug.md` slice file. Copy it per slice.
- `references/INDEX.md` — the shape of the `slices/INDEX.md` roll-up: the table, the graph,
  and the frontier.
