---
name: dw-conform
description: >-
  Check a change for conformance with the repo's existing, pre-committed patterns — its
  siblings — and write a durable conform.md to `.ai/verify/`: a verdict plus drift findings,
  each a real `file:line` paired with the pre-existing pattern it diverges from (confirmed via
  `git log` to pre-date the change). A different axis from dw-review: not internal quality but
  fit with established patterns. Self-contained and read-only — grounds each finding in a
  pre-existing referent, never treats a file this change introduced as the pattern, and reports
  honestly when there's no precedent instead of inventing drift. Resolves the change three ways
  (working diff, branch vs base, or PR via `gh pr diff`). Use when a change is ready for review
  or about to merge, or when someone says "does this match our patterns", "is this consistent
  with the codebase", "check for drift", "consistency check", or invokes "dw-conform". Prefer
  this over an ad-hoc consistency gut-check whenever a change should match existing patterns.
argument-hint: "What should I check for conformance? (working diff, branch, or PR)"
---

# dw-conform — does the change fit the patterns the repo already set?

A change is written, maybe about to go up as a PR — and one valuable question before it merges isn't
"is this code good?" but "does it look like the rest of this repo?". Any codebase that has lived a
while already has a way of doing things: how it structures modules, names symbols, handles errors,
calls the database, writes tests. A change that ignores those established patterns isn't necessarily
_wrong_ — that's `dw-review`'s question — but it's **drift**: now there are two ways to do the same
thing, and the next person has to wonder which one to copy. This skill checks the change against the
patterns the repo already established and captures the drift as a durable artifact, `conform.md`.

The whole point is **grounded against something real and _pre-existing_**. Conformance only means
something when it's measured against a pattern that already exists — a sibling file that was there
before this change. So every finding here pairs the drifting line with the established line it
diverges from, both real; "conforms — no drift" is a valid, honest result, not a quota to fill; and
the trap unique to this skill — treating a file _this very change_ introduced as if it were the
standard — is one you actively avoid. A change can't be the convention for itself.

## Output location

Write to `.ai/verify/<branch-slug>/conform.md`. `.ai/` is tracked in git — a conformance check is
real work documentation, committed alongside the code.

- Branch: `git rev-parse --abbrev-ref HEAD`. Slugify it for the folder name
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the **same slug** the rest of
  `dw-quality` uses, so your `conform.md` lands beside its siblings.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Input — read your neighbours first (if they exist)

`dw-conform` runs early in the pipeline — usually right after `dw-review`, before the
explain / verify / risk chain. The shared folder may already hold a sibling output, so check first:

- If **`review.md`** (from `dw-review`) is there, read it — a reviewer's findings often overlap with
  drift (an architecture comment is frequently a conformance problem seen from the quality side), and
  it points you at the areas worth looking hardest at.
- If **`explain.md`** (from `dw-explain`) is there, read it for the change's _intent_ — knowing what
  the change is _for_ helps you tell deliberate divergence from accidental drift.
- Any other sibling output is context, not a gate.

**Self-contained.** `dw-conform` depends on no sibling having run. With an empty folder, check
straight from the diff. Either way, **always write `conform.md`** — even "conforms, no drift" is a
durable result worth recording. Never finish a run with no artifact.

## Resolve the change (three input shapes)

The request — which change to check — may arrive as `$ARGUMENTS`. You need the diff both to locate
the right branch-slug folder and to ground every finding. Accept any of three shapes; pick by what
the user pointed at, else default to the working diff:

1. **Working diff** (default): `git diff $(git merge-base HEAD <base>)` (base is usually `main`; read
   it from the project's git conventions if declared).
2. **Branch vs an explicit base**: `git diff <base>...HEAD`.
3. **PR**: `gh pr diff <number>` (or `gh pr diff` on the current branch's PR).

Read the actual diff. Every finding below is anchored in these hunks and in the pre-existing files
they diverge from, not in your memory of the change.

## Find the established pattern (don't impose a generic standard)

Conformance is measured against _this_ repo's own patterns, never a generic ideal or your own taste.
"I'd structure it differently" is noise; "this diverges from how `lib/http.ts` already does it" is
signal. And the pattern must be something the repo **already established** — not something this change
introduces. Discover, read-only, in this order:

1. **Declared block** — `## Commands` / `## Project specifics` / coding conventions in `CLAUDE.md`,
   `CLAUDE.local.md`, or `AGENTS.md` (naming, the layers, where things live, the chosen libraries).
2. **Precedent files — the siblings** — the existing files that do the _same kind of thing_ the
   change does (another controller, another migration, another test). Find them by structure (a
   `controllers/` directory, a `*_spec.rb` neighbour) and by history: `git log` tells you which files
   pre-date this change (see the guard below). These are your pattern-referents.
3. **Manifests / config** — `package.json` / `Gemfile` / `go.mod` and the linter / formatter config.
   Their presence tells you the stack, so you compare like with like — a Ruby idiom isn't a Go idiom.
4. **The code itself** — the surrounding, unchanged code is the living convention.

This is reading, not running — `dw-conform` never executes anything (that's `dw-verify`, under its
execution guard). The pattern always comes from the project in front of you, never from a convention
baked into this skill.

## The pre-existing-pattern guard — conform to what was already there

This is the heart of the skill, and the one place it's easy to fool yourself. A pattern is only a
pattern if it **pre-dates the change** — otherwise the check is circular.

- **Confirm the referent pre-exists.** Before citing a `file:line` as _the pattern_, confirm it isn't
  part of this change. The diff already tells you what's new; for anything you're unsure of,
  `git log <base>..HEAD -- <file>` (or `git log -1 -- <file>`) shows whether this branch introduced
  it. Cite only files that were there before.
- **Never let the change define its own standard.** If the diff adds three handlers in a new style,
  that new style is the _subject_ of the check, not the pattern — compare it to the handlers that
  already existed, not to itself. A fresh mistake repeated twice in the same PR is not "the
  convention".
- **No precedent → say so, don't fabricate.** If a changed area is genuinely the first of its kind (a
  brand-new concern, no sibling to compare against), there is no drift to report — record it under
  _No-precedent notes_, honestly. Inventing a convention just so you have something to flag is the
  exact failure this skill exists to prevent.

## Ground every finding — the anti-hallucination invariant

**No drift in `conform.md` without _two_ real referents.** Every finding points at both: a `file:line`
in the change (where it drifts) **and** a pre-existing `file:line` (the established pattern it diverges
from). A divergence you can't anchor to an existing pattern isn't drift — it's an opinion. A vague
"this should be more consistent" with no location is not a finding; "`api/users.ts:20` opens a raw
`fetch`, but every other caller routes through `lib/http.ts:12`" is.

## Scope discipline — conformance, not quality

`dw-conform` checks one thing: fit with established patterns. It is **not** `dw-review`. A bug, a
security hole, or a slow query that is _consistent_ with the rest of the repo is out of scope here —
it belongs in `review.md`. (And the converse holds: clean, correct code can still drift.) Keeping the
axis narrow is what makes this artifact worth reading. The opposite failure is just as real: **don't
manufacture drift to look thorough.** A change that matches the repo is a legitimate result — write
"— none —" and mean it.

## The verdict

Roll the drift findings up into one verdict, by the worst drift present. Each finding carries a light
severity so the verdict is legible at a glance:

- **high** — a structural divergence: a different architecture / layer, a bypassed shared utility, a
  contradicted convention. The kind of thing that should be aligned before merge.
- **medium** — a real but contained divergence; works and reads fine, but isn't how the repo does it.
- **low** — cosmetic: naming, ordering, anything a formatter or linter would settle.

**Verdict** = the worst severity present:

- any **high** → **drifts**;
- only **medium** / **low** → **minor-drift**;
- none → **conforms**.

## What goes in conform.md

A light frontmatter, the **Verdict**, a single **Drift findings** table — each row
`severity · location (in the change) · drift · pattern referent (pre-existing) · suggested alignment`
(or "— none —" when the change conforms) — a short **No-precedent notes** list for first-of-their-kind
areas that are honestly _not_ drift, and a one-paragraph **Summary** that leads with the verdict. Keep
it lean: it's drift the author reads and acts on, not a report.

## Workflow

### 1. Locate the input and read neighbours

Resolve the branch-slug and look in `.ai/verify/<branch-slug>/`. Read `review.md` if present (its
findings point you at likely drift) and `explain.md` for intent. Their absence is normal.

### 2. Resolve the diff and read the project's conventions

Pick the input shape, read the diff, and read the declared conventions (read-only). Now you know what
the change _is_ and which rules the project states for itself.

### 3. Find the established patterns (the siblings)

For each _kind_ of thing the change introduces or modifies, find the pre-existing files that already
do that kind of thing — the precedent set. Use structure and `git log` to confirm they pre-date the
change. This is your referent set for everything below.

### 4. Identify drift, grounded in pre-existing referents

Compare the change against each precedent. Record each divergence with **both** referents — the
drifting line and the established line. Apply the guard: drop anything whose "pattern" is actually
part of this change, and set aside first-of-their-kind areas for _No-precedent notes_ rather than
forcing a finding.

### 5. Assign severity and derive the verdict

Give each finding a severity (high / medium / low), and roll them up: any high → drifts; only
medium / low → minor-drift; none → conforms.

### 6. Write conform.md

Copy the shape from `references/conform.md`. Ground every row with both referents; mark a conforming
change "— none —"; list first-of-their-kind areas under _No-precedent notes_.

### 7. Finalize and point to the next step

Tell the user where the artifact landed and what the verdict is, then point forward — a pointer, not
a dependency:

> `conform.md` saved to `.ai/verify/<branch-slug>/` — verdict: **`<verdict>`**. **Next:** `dw-fix` to
> address the drift, then `dw-explain` to explain the change and generate verification scenarios.

Lead with the significant (high) drifts so the author knows what to align first.

## The conform.md shape

`references/conform.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created` / `sources`), a **Verdict** line, a **Drift findings** table
(`Severity · Location · Drift · Pattern referent · Suggested alignment`, or "— none —"), a
**No-precedent notes** list, and a short **Summary**. Keep it lean — drift the author can act on, not
prose.

## References

- `references/conform.md` — the artifact template. Copy this shape every run.
