---
name: dw-risk
description: >-
  Assess a change's blast radius and out-of-code impact, and write a durable
  risk.md to `.ai/verify/`: (a) what it touches, in impact tiers; (b) out-of-code
  work (DB migrations, env vars, feature flags, infra, secrets); (c) follow-ups and
  rollback, with every irreversible step flagged as a one-way-door. Analytical and
  read-only — it reads the diff plus any neighbouring review.md / conform.md /
  explain.md / verify-run.md, detects stack signals from the project, and never
  executes anything. Grounds every item in a real referent; a section it can't
  ground is marked NOT VERIFIED, not a false "no risk". Resolves the change three
  ways (working diff, branch vs base, or a PR via `gh pr diff`). Use when a change
  is about to merge or deploy, or when someone says "what's the blast radius", "what
  could this break", "assess the risk", "is this migration safe", "what's the
  rollback plan", or invokes "dw-risk".
argument-hint: "What should I assess for risk? (working diff, branch, or PR)"
---

# dw-risk — map the blast radius, name the out-of-code work, plan the rollback

A change is written, maybe explained and verified — and now it's about to merge or deploy.
The valuable next step is to ask the questions that don't show up in a green test run: **what
does this touch beyond the lines it changed? what has to happen outside the code merge — a
migration, an env var, a flag flip? and if it goes wrong, how do we get back?** That thinking
normally happens in the moment and then evaporates: the next reviewer, or the person doing the
deploy at 2am, can't see it. This skill captures it as a durable artifact, `risk.md`, holding
the blast radius (in tiers), the out-of-code work, and the follow-ups and rollback.

The whole point is **grounded, not guessed**. A risk list invented from intuition is worse than
none — it sends people chasing impact that isn't there and lulls them past the impact that is.
So every item here traces to something real in the change, and when you genuinely can't ground a
section you say so (`NOT VERIFIED`) rather than writing a comforting "no risk". This is the
analytical sibling of `dw-verify`: it does not _run_ anything, it _reasons_ about what running it
in production would set in motion.

## Output location

Write to `.ai/verify/<branch-slug>/risk.md`. `.ai/` is tracked in git — risk assessment is real
work documentation, committed alongside the code.

- Branch: `git rev-parse --abbrev-ref HEAD`. Slugify it for the folder name
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the **same slug** `dw-explain`
  and `dw-verify` used, so your `risk.md` lands beside their artifacts.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Input — read your neighbours first

The whole `dw-quality` cluster writes to this same folder, and `dw-risk` reads it as input:

- **`review.md` / `conform.md`** (from `dw-review` / `dw-conform`) are your **primary
  blast-radius input** — they already name what a reviewer flagged as risky or non-conforming,
  which is exactly where the impact concentrates. Fold their findings into your tiers.
- **`explain.md` / `verify-run.md`** (from `dw-explain` / `dw-verify`) tell you what the change is
  _for_ and what actually proved out. Reuse that — don't re-derive the mechanism, and don't
  re-assess as risky something `dw-verify` already PASSED with evidence.

**Self-contained fallback.** `dw-risk` does not depend on any sibling having run. If none of
those files exist, **derive the risk from the diff yourself** — resolve the change (next
section), find the referents, and assess the three sections directly from the hunks. Either way,
**always write `risk.md`**: an honest assessment that is mostly `NOT VERIFIED` is itself a
finding. Never finish a run with no artifact.

## Resolve the change (three input shapes)

The request — which change, and which areas to weigh — may arrive as `$ARGUMENTS`. You need the
diff both to locate the right branch-slug folder and to ground every item. Accept any of three
shapes; pick by what the user pointed at, else default to the working diff:

1. **Working diff** (default): `git diff $(git merge-base HEAD <base>)` (base is usually `main`;
   read it from the project's git conventions if declared).
2. **Branch vs an explicit base**: `git diff <base>...HEAD`.
3. **PR**: `gh pr diff <number>` (or `gh pr diff` on the current branch's PR).

Read the actual diff. Everything below is grounded in these hunks, not in your memory of the
change.

## Read the project's signals (don't hardcode a stack)

`dw-risk` **analyses, it does not execute** — this is the line between it and `dw-verify`. To
judge out-of-code impact you need to know what _counts_ as a migration, a flag, or a secret in
**this** project, and that fact comes from the project, never from a stack assumption baked into
the skill. Discover, read-only, in this order:

1. **Declared block** — `## Commands` / `## Project specifics` in `CLAUDE.md`, `CLAUDE.local.md`,
   or `AGENTS.md` (where migrations live, how flags are toggled, where env/secrets are declared,
   the deploy target).
2. **Manifests / conventions** — `package.json`, `Gemfile` + `db/migrate/`, `Makefile`,
   `Procfile`, IaC files (`*.tf`, `docker-compose.yml`, k8s manifests), `.env.example`. Their
   presence is also how you detect the stack (Gemfile → Rails migrations, etc.).
3. **The code itself** — when neither declares it, infer from what you can read.

Detecting these signals is reading, not running. Never apply a migration, flip a flag, or hit an
environment to "check" — that's `dw-verify`'s job, under its execution guard.

## Ground every line — the anti-hallucination invariant

**No item in `risk.md` without a verified referent.** Every entry — every touched area, every
migration, env var, flag, infra change, secret — must trace to something that demonstrably exists
in _this_ change or _this_ repo:

- a blast-radius area → a path in the diff, or a caller you found via `Read` / search;
- a migration → a migration file in the diff, or a schema change you can point to;
- a flag / env var / secret → a name referenced in the changed code or a config file you read;
- an infra change → a changed IaC / deploy manifest in the diff.

If you cannot ground an item, it does **not** become a confident-looking guess. It is the line
between an artifact someone can act on and one that wastes a reviewer's nerves. When in doubt,
mark it `NOT VERIFIED` (below) rather than assert it.

## The migration-safety guard — name the one-way-doors

This is the heart of the skill. Most code is reversible: revert the commit, redeploy, done. Some
changes are not — and those are where a calm pre-deploy assessment earns its keep. As you read the
diff, flag every step that **cannot be cleanly undone by reverting the code** as a
**one-way-door**:

- a dropped or renamed column / table, or any destructive (non-reversible) migration;
- data deleted, truncated, or backfilled in place;
- a removed or renamed endpoint, or a changed request/response contract clients depend on;
- a published event/message-schema change, or anything already consumed downstream by the time
  you'd want to roll back.

For **every migration**, state a concrete rollback plan — the down-migration, the restore path,
the compatibility window — **or say plainly that there is none**. "There is no rollback for this"
is a valid, important finding; a missing rollback section that _looks_ fine is not. A change with
a one-way-door isn't necessarily wrong — but it must be named, so the decision to walk through it
is made on purpose.

## When you can't ground it: NOT VERIFIED

A section or item you cannot anchor to a real referent gets **NOT VERIFIED**, with the missing
referent named — never a false "no risk / nothing to do". This is the analytical analog of
`dw-verify`'s `INCONCLUSIVE`: first-class, not a cop-out.

The trap to avoid is the **silent pass**: writing "Out-of-code: none" when you simply didn't
confirm there were no migrations or flags. An empty section is only honest if you actually
checked and found nothing; otherwise it is `NOT VERIFIED`. See `references/not-verified-rubric.md`
for exactly where the line sits.

## What goes in risk.md — the three sections

1. **(a) Blast radius + tiers** — what the change touches, bucketed by how far the impact reaches:
   `core` (the change's own path; if this breaks, the feature is broken), `secondary` (callers,
   shared modules, adjacent features that route through the changed code), `isolated` (self-
   contained, no downstream reach). Every area cites a real path.
2. **(b) Out-of-code** — everything that must happen _besides merging the code_: DB **migrations**,
   **env vars**, **feature flags**, **infra** (scaling, queues, cron, DNS), **secrets**. Each row
   says what action is required and whether it's a one-way-door.
3. **(c) Follow-ups + rollback** — what to do _after_ deploy (backfill, monitor, flip a flag,
   announce a breaking change), how to undo each piece, and which steps are one-way-doors with no
   undo.

See `references/blast-radius-taxonomy.md` for the tier definitions, the per-kind out-of-code
checklist, and the one-way-door signals.

## Workflow

### 1. Locate the input and read neighbours

Resolve the branch-slug and look in `.ai/verify/<branch-slug>/`. Read any `review.md` /
`conform.md` (primary blast-radius input) and `explain.md` / `verify-run.md` (what's already
explained / proved). Their absence is fine — fall back to the diff.

### 2. Resolve the diff and read the project's signals

Pick the input shape, read the diff, and read the project's migration / flag / env / infra
conventions (read-only). This is your referent set for everything below.

### 3. Build the blast radius and assign tiers

For each touched area, trace its reach and bucket it `core` / `secondary` / `isolated`, grounded
in real paths. Pull in what `review.md` / `conform.md` already flagged.

### 4. Enumerate the out-of-code items

Walk the checklist — migrations, env, flags, infra, secrets — against the diff and the project's
conventions. Each item gets an action and a one-way-door verdict, or it's `NOT VERIFIED`.

### 5. Derive follow-ups and rollback; flag one-way-doors

For each migration / breaking change, write the rollback (or "none"). List post-deploy follow-ups.
Mark every irreversible step.

### 6. Write risk.md

Copy the shape from `references/risk.md`. Fill the three sections; ground every row; mark the
ungroundable `NOT VERIFIED`.

### 7. Finalize and close the chain

Tell the user where the artifact landed and **close the loop** — `dw-risk` is the terminal skill
of the `dw-quality` pipeline (`… → dw-verify → dw-risk → ship`), so there is no "next skill":

> `risk.md` saved to `.ai/verify/<branch-slug>/` — this closes the `dw-quality` pass. Review the
> blast radius, the out-of-code items, and the rollback before you merge or deploy.

If any section came out `NOT VERIFIED`, name it and say it's the one thing to resolve by hand
before shipping.

## The risk.md shape

`references/risk.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created` / `sources`) plus the three sections — **(a) Blast
radius** (a small `Area · Tier · What changes · Referent` table), **(b) Out-of-code** (a
`Kind · Item · Action required · Referent · One-way-door?` table), and **(c) Follow-ups &
rollback**. Keep it lean — it's a pre-deploy checklist, not a report.

## References

- `references/risk.md` — the artifact template. Copy this shape every run.
- `references/blast-radius-taxonomy.md` — read when filling sections (a) and (b): the impact-tier
  definitions, the out-of-code checklist (migrations / env / flags / infra / secrets) with the
  signals that betray each, and the one-way-door list. Per-stack snippets are illustrative
  examples, never logic.
- `references/not-verified-rubric.md` — read when deciding whether an item is grounded or
  `NOT VERIFIED`: exactly where the line sits, and why an unchecked-but-empty section is a silent
  pass, not a clean bill of health.
