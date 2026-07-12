---
name: dw-prune
description: >-
  Propose a grounded keep, merge, or delete plan for redundant tests, then mutate only after explicit
  approval and re-run project tests. Writes .ai/verify/prune.md and preserves real coverage. Use
  explicitly for "prune tests", "remove redundant tests", or "dw-prune".
argument-hint: "Which tests to prune? (working diff, branch, PR, or a path to widen the scope)"
disable-model-invocation: true
---

# dw-prune — trim redundant tests without losing coverage

Use expanded invocation arguments when available. If the host leaves literal `$ARGUMENTS`, ignore
the placeholder and infer scope from the user's prompt.

A change lands and, over time, the test suite around it has quietly accreted weight: two tests that
assert the same behavior in slightly different words, a test for a code path this change just
deleted, a narrow case fully subsumed by a stronger sibling that came later. None of that is _wrong_
— but it's drag. A bloated suite runs slower, reads noisier, and trains the next person to copy the
duplication. This skill finds the tests worth trimming around a change and captures the plan as a
durable artifact, `prune.md` — then, with your say-so, actually trims them.

The whole point is that **coverage is the floor, never the casualty**. A redundant test costs
milliseconds; deleting the _only_ test for a behavior costs a silent production regression that
ships unnoticed — the one unrecoverable mistake here. So a test may be merged away or deleted only
when a _named, retained_ test still catches the same behavior. And because this is the one
`dw-quality` skill that **mutates files**, it never edits on a hunch: it writes the plan first and
STOPS, and touches a test only after you explicitly approve it.

## Output location

Write to `.ai/verify/<branch-slug>/prune.md`. `.ai/` is tracked in git — a prune plan is real work
documentation, committed alongside the code.

- Branch slug for the folder name —
  `bash "<runtime-dir>/slugify.sh" branch-slug "$(git rev-parse --abbrev-ref HEAD)"`
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the **same slug** the rest of
  `dw-quality` uses, so your `prune.md` lands beside its siblings.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Input — read your neighbours first (if they exist)

`dw-prune` runs mid-pipeline — after `dw-review` / `dw-conform`, before the explain / verify / risk
chain. The shared folder may already hold a sibling output, so check first:

- If **`review.md`** (from `dw-review`) is there, read it — the files a reviewer flagged as heavily
  changed are exactly where redundant or stale tests cluster, so it points you at the candidates.
- If **`conform.md`** (from `dw-conform`) is there, read it for the same reason — a drift hotspot is
  often a test hotspot.
- Any other sibling output is context, not a gate.

**Self-contained.** `dw-prune` depends on no sibling having run. With an empty folder, work straight
from the diff. Either way, **always write `prune.md`** — even "nothing to prune, every test earns
its place" is a durable result worth recording. Never finish a run with no artifact.

## Resolve the change (three input shapes)

The request — which tests to prune — may arrive as `$ARGUMENTS`. You need the diff both to locate
the right branch-slug folder and to ground every decision. Accept any of three shapes; pick by what
the user pointed at, else default to the working diff:

1. **Working diff** (default): `git diff $(git merge-base HEAD <base>)` (base is usually `main`; read
   it from the project's git conventions if declared).
2. **Branch vs an explicit base**: `git diff <base>...HEAD`.
3. **PR**: `gh pr diff <number>` (or `gh pr diff` on the current branch's PR).

Scope is **the tests related to the change** (the diff) by default. `$ARGUMENTS` can widen or
redirect it — e.g. "prune the whole `spec/models` dir" — but the same coverage guard applies whatever
the scope.

## Read the project's test layout and command (don't hardcode a stack)

Both _where tests live and how they're named_ **and** _the command that runs them_ come from the
project in front of you, never from a convention baked into this skill. A Ruby suite isn't a Go
suite; one repo's `spec/` is another's `__tests__/`. Discover, read-only, in this order:

1. **Declared block** — `## Commands` / `## Project specifics` in `CLAUDE.md`, `CLAUDE.local.md`, or
   `AGENTS.md` (the test command, the test directory, the naming convention).
2. **Manifests / scripts** — `package.json` scripts, `Gemfile` + `bin/`, `Makefile`, `pyproject.toml`,
   … (also how you detect the stack and its test-file shape: Gemfile → Ruby / `*_spec.rb`,
   package.json → Node / `*.test.ts`, go.mod → Go / `*_test.go`).
3. **The code itself** — the existing test files are the living convention for layout and naming.

If the test command can't be resolved, you can still produce the _plan_ — but you cannot do the
post-edit verification below. Say so honestly rather than papering over the gap.

## The regression-safety gate — coverage is the floor

This is the heart of the skill, and the one place it's easy to fool yourself. The gate is a single,
hard invariant:

> A test may be marked **delete** (or merged away) **only when a named, retained test (`file:line`)
> catches the same behavior.** If no retained test covers a behavior, the verdict is **keep** —
> never delete.

The reasoning is asymmetric on purpose: a redundant test that survives wastes a little time; a
unique test that's deleted removes the only guard on a behavior, and the regression ships in silence.
When in doubt, keep. Two traps to watch:

- **Partial overlap is not redundancy.** A test that covers behaviors A _and_ B, where only A is
  retained elsewhere, must be **keep** or **merge** — never **delete**. You'd be dropping B.
- **Same file is not same behavior.** The retained test must actually _assert_ the behavior in
  question, not merely touch the same module or fixture. "Covered by `foo_spec.rb`" is not enough;
  "`foo_spec.rb:40` asserts the blank-email rejection" is.

## Ground every finding — the anti-hallucination invariant

**No keep / merge / delete decision without a verified referent.** Every row points at a real test
at `file:line` — one you opened with `Read` or that appears in the diff, not one you remember
existing. For a **merge** or **delete**, the _retained_ test referent is equally mandatory and
equally real: you must be able to name the `file:line` that still covers the behavior. A decision you
can't anchor to a real test isn't a finding — it's a guess, and here a guess can delete code.

## Scope discipline — trim, don't rewrite

`dw-prune` does one thing: it **trims** (merge / delete). Its boundaries cut both ways.

- A test that is stale or wrong but _uniquely_ covers a behavior → **keep**, and flag it in Notes.
  Do **not** rewrite its assertions, repair a broken test, or touch production logic — that's
  implementation work, not pruning, and it belongs in a build/fix pass, not here.
- Don't manufacture redundancy to look busy. A suite with no real overlap is a legitimate, common
  result — write "— none —" and mean it.

## The verdict

Roll the rows up into one verdict, legible at a glance:

- **prunable** — at least one **merge** or **delete** is proposed.
- **clean** — nothing to prune; every test earns its place.
- **blocked** — a test _looks_ redundant but has no retained test covering its behavior, so the gate
  forces it to **keep**. Surface it: coverage is thinner there than the duplication suggested.

## What goes in prune.md

A light frontmatter, the **Verdict**, a single **Prune plan** table — each row
`action · test (file:line) · behavior covered · retained by (file:line) · notes` (or "— none —" when
there's nothing to prune) — a **Result** line for the post-edit test run, and a one-paragraph
**Summary** that leads with the verdict and the keep / merge / delete counts. Keep it lean: it's a
plan the author reads and acts on, not a report.

## The consent gate — propose first, edit only on the user's word

This is where `dw-prune` differs from every read-only sibling: its output _is_ a plan to mutate
files. So the plan and the mutation are two separate steps, and the second never happens on its own.

- **Write the full plan to `prune.md` first, then STOP.** Present the keep / merge / delete table to
  the user. At this point no test has been touched.
- **Ask how to proceed**, offering three modes: **batch** (apply every merge / delete row),
  **per-row** (name the rows to apply, e.g. "rows 2, 5, 7"), or **none** (plan only).
- **Without explicit consent, touch nothing.** "Plan only" is a correct, complete outcome —
  `prune.md` stands on its own. Never delete on silence, on inference, or on a vague "looks good";
  wait for an explicit instruction.
- On **partial** approval, apply only the approved rows and mark the rest in `prune.md` as
  `proposed (not applied)`, so the record matches what's on disk.

## Post-edit verification — prove the suite is still green

Trimming tests is only safe if the suite still passes afterward. After applying approved edits:

- **Run the project's own test command** (the one you resolved above) and record the outcome in
  `prune.md`'s **Result** line: **GREEN** with a short evidence excerpt (the pass count, the decisive
  line), **RED** with the failing test named (the prune is **not** confirmed — surface it and offer to
  revert), or **UNVERIFIED** if the command couldn't be resolved or the suite can't run in this
  session.
- **Never claim success without a green run in hand.** A prune you couldn't verify is an honest
  UNVERIFIED, not a quiet pass — the same evidence-not-assertion discipline `dw-verify` holds.

## Workflow

### 1. Locate the input and read neighbours

Resolve the branch-slug and look in `.ai/verify/<branch-slug>/`. Read `review.md` and `conform.md` if
present — the areas they flag as churn are where redundant or stale tests cluster. Their absence is
normal; `dw-prune` is self-contained.

### 2. Resolve the change and read the project's test layout + command

Pick the input shape (working diff / branch / PR), read the diff, and discover — read-only — where
tests live, how they're named, and the command that runs them. Scope is the tests related to the
change by default; `$ARGUMENTS` can widen or redirect it.

### 3. Find the candidate tests

From the diff (and any churn signals from the neighbours), gather the tests touching or covering the
changed code. Open each one with `Read` and name the behavior it actually asserts — this is the
referent set everything below is built on.

### 4. Classify each candidate, grounded in referents

For every candidate decide **keep / merge / delete**, anchored to a real test at `file:line`. For any
**merge** or **delete**, identify the named, retained test (`file:line`) that still catches the same
behavior. No decision without a verified referent — that's the invariant, not a formality.

### 5. Apply the regression-safety gate

Walk every proposed **merge** / **delete** and confirm its retained test genuinely _asserts_ the same
behavior. If no retained test covers a behavior, downgrade the row to **keep** and flag the thin
coverage in Notes. Coverage is the floor: a test goes only when its behavior survives elsewhere.

### 6. Write prune.md — then STOP

Copy the shape from `references/prune.md`. Fill the verdict, the keep / merge / delete table (every
merge / delete naming its retainer), and the Summary. Mark a suite with no overlap "— none —". Write
the file. **Do not edit any test yet.** Present the plan to the user.

### 7. Get explicit consent

Ask how to proceed — **batch**, **per-row**, or **none**. Without explicit consent, touch nothing;
`prune.md` is already a complete deliverable.

### 8. Apply the approved edits

Apply only the approved rows: delete the doomed tests, fold merged assertions into their retainer.
Mark any unapproved rows in `prune.md` as `proposed (not applied)`. This is the only step that
mutates files.

### 9. Run the project's test command and record the result

Run the suite with the project's own command. Record GREEN (+ excerpt), RED (failing test named —
prune not confirmed, offer to revert), or UNVERIFIED into `prune.md`'s **Result** line. Never claim
success without a green run.

### 10. Finalize and point to the next step

Tell the user where the artifact landed, the verdict, and what was applied, then point forward — a
pointer, not a dependency:

> `prune.md` saved to `.ai/verify/<branch-slug>/` — verdict: **`<verdict>`** (`n` kept · `n` merged ·
> `n` deleted; suite **GREEN**). **Next:** consider `dw-explain` to explain the change and generate
> runnable verification scenarios.

## The prune.md shape

`references/prune.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created` / `sources`), a **Verdict** line, a **Prune plan** table
(`Action · Test · Behavior covered · Retained by · Notes`, or "— none —"), a **Result** line for the
post-edit run, and a short **Summary**. Keep it lean — a plan the author can act on, not prose.

## References

- `references/prune.md` — the artifact template. Copy this shape every run.
