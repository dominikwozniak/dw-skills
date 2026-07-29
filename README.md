<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/banner-light.svg">
    <img src="assets/banner-light.svg" alt="dw-skills" width="420">
  </picture>
</p>

<p align="center"><strong>spec → plan → build → verify — a persistent, technology-agnostic workflow for Claude Code that survives a <code>/clear</code>.</strong></p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-111111?style=flat-square">
  <img alt="23 skills" src="https://img.shields.io/badge/skills-23-111111?style=flat-square">
  <img alt="4 plugins" src="https://img.shields.io/badge/plugins-4-111111?style=flat-square">
  <img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude_Code-plugin-111111?style=flat-square">
  <a href="https://github.com/dominikwozniak/dw-skills/actions"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/dominikwozniak/dw-skills/validate-plugin-manifests.yaml?style=flat-square&label=ci&color=111111"></a>
</p>

Plans and reviews land on disk under `.ai/` (tracked in git), so work survives a `/clear`, a new
session, or a handoff to another agent. Every skill reads your project's own commands and
conventions — nothing about a stack is baked in.

## ◆ Why these skills exist

These aren't theoretical. Each is a failure mode I kept hitting in day-to-day work with AI agents —
the catalog is the set of reusable steps I pulled out of that loop. Each skill kills one:

- **Context dies on /clear or a handoff** — plans and reviews persist as tracked `.ai/` files;
  `dw-resume` picks the work back up, `dw-handoff` packs it for the next agent.
- **The agent runs on a wrong assumption** — `dw-spec` forces the unknowns to the surface as a
  numbered Open-Questions gate and HARD STOPS until you answer.
- **"Done" is claimed but never proven** — `dw-explain` writes runnable scenarios; `dw-verify` runs
  them and never reports PASS without captured output.
- **The work is too big for one plan** — `dw-split` decomposes a spec into a dependency graph of
  slices with a takeable frontier, instead of one spine no single session can finish.
- **The plan silently drifts from the code** — `dw-sync` re-aligns `PLAN.md` with what actually shipped.
- **A change merges on an eyeball, not a real pass** — `dw-review` / `dw-conform` / `dw-risk` weigh it
  across axes, against the repo's own patterns, and for blast radius.
- **Review findings have nowhere to land** — `dw-fix` applies them: the one writer in the quality
  pipeline, severity-gated (blockers first), one commit per fix.
- **The test suite bloats** — `dw-prune` trims redundant tests without dropping coverage.
- **The process outweighs the change** — a repo only you read doesn't need three planning artifacts and
  five audits. `dw-solo` is the same loop at one file and one pass.

The _why_ behind each design choice is in [`docs/DESIGN.md`](docs/DESIGN.md).

## ▸ Quick start

```
claude plugin marketplace add git@github.com:dominikwozniak/dw-skills.git
claude plugin install dw-misc       # bootstrap · git · handoff · doctor · setup-precommit

# then pick ONE lane per repo — see "Two lanes" below
claude plugin install dw-planning   # team: spec → plan → split → build → resume → sync
claude plugin install dw-quality    # team: review · conform · fix · prune · explain · verify · risk
claude plugin install dw-solo       # solo: init · grill · shape · next · land
```

**Team repo** — `/dw-bootstrap` once, then start a feature with `/dw-spec` and resume after a `/clear`
with `/dw-resume`.

**Your own repo** — `/dw-init` once, then `/dw-shape` and `/dw-next`. `/dw-next` bare is also the
resume path.

## ↻ The workflow

> 📖 New here? [**`docs/WORKFLOWS.md`**](docs/WORKFLOWS.md) is the guided tour — the loop
> walked step by step, a recipe for each situation (start a feature, resume after a
> `/clear`, review before a PR, fix findings, reconcile drift), and the decisions between
> skills. The map below; that's the tour.

### The core loop — team lane

```
  SPEC         PLAN         BUILD                   REVIEW · VERIFY           SHIP
  /dw-spec  →  /dw-plan  →  /dw-build       →       /dw-review  /dw-explain → (open PR — your own tooling)
             ↳ /dw-split (too big for one plan → slice graph)
                          ↺ /dw-resume (pick up)    /dw-conform /dw-verify
                            /dw-sync (fix drift)    /dw-prune   /dw-risk
  └────────────── .ai/runs/<id>/ ──────────────┘    └─ .ai/verify/<branch-slug>/ ─┘
```

### The same loop, solo lane

For repos only you read. One artifact instead of three, one quality pass instead of five.

```
  (GRILL)       SHAPE           BUILD                 LAND                    SHIP
  /dw-grill →   /dw-shape   →   /dw-next     →        /dw-land         →      (open PR — /dw-git)
  fuzzy idea    one CHANGE.md   ↺ /dw-next (bare =    verdict, then promote
                + task list       resume from disk)   decisions & drop the doc
  └────── .ai/work/<slug>/CHANGE.md (deleted at merge) ──────┘  └→ docs/decisions/ · CONTEXT.md · ## Gotchas · .ai/BACKLOG.md (kept)
```

**Pick one lane per repo** — installing both means two skills compete for "start a feature". Why the
two exist and what the solo lane drops: [`docs/DESIGN.md`](docs/DESIGN.md), "Two lanes, one toolbox".

`<branch-slug>` = the current branch slugified, e.g. `ABC-123/password-reset` →
`abc-123-password-reset`. SHIP — deciding when to open the PR, plus the deploy/CI that follows — is
intentionally outside this toolkit (see [`docs/DESIGN.md`](docs/DESIGN.md), "Composable, not
chained").

### Acting on findings

`/dw-fix` is the one writer in the loop — it applies the `dw-review` / `dw-conform` / `dw-risk`
findings the auditors record (blockers first, one commit per fix), then you re-audit to confirm —
required after blockers, optional after a medium/low-only pass.

### Anytime

- `/dw-git` — commit / push / PR / sync / branch / stash, by your `CLAUDE.local.md` conventions.
- `/dw-handoff` — compact the session context for the next agent.

### Setup (once per repo)

- `/dw-bootstrap` — scaffold a repo for this loop (tracked `.ai/` + `.claude/`).
- `/dw-doctor` — read-only health check of the tools and hooks the loop assumes.
- `/dw-setup-precommit` — wire git-level husky + lint-staged pre-commit hooks.

A recommendation, not a rail: every skill stands alone and is invoked when you need it. They
compose through the shared `.ai/` artifacts + a "Next:" pointer at the end of each skill.

## ◇ Task router — which skill for which task

A task may match several rows — read all that apply. `⭑` = explicit-invoke only: say its name (it
never auto-fires). The phrases that trigger each skill live in its own `description`, not here.

**Setup**

| Skill                                                          | Task                                                        | What you get                     |
| -------------------------------------------------------------- | ----------------------------------------------------------- | -------------------------------- |
| [`dw-bootstrap`](skills/dw-bootstrap/SKILL.md) `⭑`             | Scaffold a repo for the dw-\* loop: `.ai/`, settings, hooks | tracked `.ai/` + `.claude/`      |
| [`dw-init`](skills/dw-init/SKILL.md) `⭑`                       | Same for the **solo** lane: `.ai/work/`, `docs/decisions/`  | solo scaffold (smaller)          |
| [`dw-doctor`](skills/dw-doctor/SKILL.md)                       | Diagnose tools, hooks, `.ai/` sanity (read-only)            | health report + fixes            |
| [`dw-setup-precommit`](skills/dw-setup-precommit/SKILL.md) `⭑` | Wire husky + lint-staged for a pnpm node/ts/js repo         | `.husky/` + `.lintstagedrc.json` |

**Solo lane** — one file, one pass. Pick this lane _or_ the team lane below, per repo.

| Skill                                  | Task                                                       | What you get                                        |
| -------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------- |
| [`dw-grill`](skills/dw-grill/SKILL.md) | Interview a fuzzy idea into decisions — max five questions | shared understanding (writes nothing)               |
| [`dw-shape`](skills/dw-shape/SKILL.md) | Synthesize it into one goal + decisions + task checklist   | `.ai/work/<slug>/CHANGE.md`                         |
| [`dw-next`](skills/dw-next/SKILL.md)   | Resume point _and_ build step (`go` builds and commits)    | code + ticked box + commit                          |
| [`dw-land`](skills/dw-land/SKILL.md)   | One verdict: correct · fits · blast radius · proven        | `docs/decisions/` · `CONTEXT.md` · `.ai/BACKLOG.md` |

**Team lane** — spec, plan, build.

| Skill                                      | Task                                                         | What you get                     |
| ------------------------------------------ | ------------------------------------------------------------ | -------------------------------- |
| [`dw-spec`](skills/dw-spec/SKILL.md)       | Start a feature; surface unknowns via an open-questions gate | `SPEC.md` under `.ai/runs/`      |
| [`dw-plan`](skills/dw-plan/SKILL.md)       | Turn a ready spec into thin vertical slices                  | `PLAN.md` status table           |
| [`dw-split`](skills/dw-split/SKILL.md) `⭑` | Spec too big for one plan → a dependency graph of slices     | `slices/NN-slug.md` + `INDEX.md` |
| [`dw-build`](skills/dw-build/SKILL.md)     | Build the next slice: RED → GREEN → regression → commit      | code + `done` row + SHA          |
| [`dw-resume`](skills/dw-resume/SKILL.md)   | Pick up after a `/clear`; find the first not-done step       | read-only status report          |
| [`dw-sync`](skills/dw-sync/SKILL.md) `⭑`   | Re-align the plan with the code after drift                  | reconciled `PLAN.md`             |

**Review & verify** — team lane.

| Skill                                      | Task                                                        | What you get              |
| ------------------------------------------ | ----------------------------------------------------------- | ------------------------- |
| [`dw-review`](skills/dw-review/SKILL.md)   | Multi-axis review of a diff (correctness/security/perf/…)   | `review.md` + verdict     |
| [`dw-conform`](skills/dw-conform/SKILL.md) | Check a change against the repo's existing patterns         | `conform.md` drift report |
| [`dw-explain`](skills/dw-explain/SKILL.md) | Explain a change + generate runnable verification scenarios | `explain.md` scenarios    |
| [`dw-verify`](skills/dw-verify/SKILL.md)   | Run those scenarios and record PASS/FAIL + evidence         | `verify-run.md`           |
| [`dw-risk`](skills/dw-risk/SKILL.md)       | Assess blast radius, out-of-code impact, rollback           | `risk.md`                 |
| [`dw-fix`](skills/dw-fix/SKILL.md)         | Apply those findings — severity-ordered, one commit per fix | code commits + `fix.md`   |
| [`dw-prune`](skills/dw-prune/SKILL.md) `⭑` | Trim redundant tests without dropping coverage              | keep/merge/delete plan    |

**Anytime** — either lane.

| Skill                                          | Task                                                     | What you get                       |
| ---------------------------------------------- | -------------------------------------------------------- | ---------------------------------- |
| [`dw-git`](skills/dw-git/SKILL.md)             | All git ops — commit / push / PR / sync / branch / stash | commits / PR per `CLAUDE.local.md` |
| [`dw-handoff`](skills/dw-handoff/SKILL.md) `⭑` | Compact the session for the next agent                   | `.ai/handoffs/<ts>.md`             |

Within Review & verify: `dw-explain → dw-verify` is a chain (verify runs explain's scenarios);
`dw-review` and `dw-conform` are independent axes; `dw-prune` trims redundant tests on explicit
consent; `dw-risk` reads whatever neighbours exist and closes the pipeline. `dw-fix` is the one
writer — it applies the findings the auditors record (blockers first), then you re-audit to confirm
(required after blockers, optional after a medium/low-only pass).

## ▣ Plugins — install what you need (4)

Four plugins, grouped by job. The [task router](#-task-router--which-skill-for-which-task) above says
what each skill does — here's which plugin ships it and where its artifacts land.

- **`dw-misc`** — repo setup + everyday helpers, lane-independent. `dw-bootstrap` · `dw-git` ·
  `dw-handoff` · `dw-doctor` · `dw-setup-precommit`.

Then **one lane per repo** — the two below, or the one after them:

- **`dw-planning`** — the spec→plan→build loop. `dw-spec` · `dw-resume` · `dw-plan` · `dw-split` ·
  `dw-build` · `dw-sync`. `dw-split` is the escape hatch when a spec is too big for one `PLAN.md`.
  Artifacts: `.ai/runs/<id>/`.
- **`dw-quality`** — the change-quality pipeline. `dw-review` · `dw-conform` · `dw-fix` · `dw-prune` ·
  `dw-explain` · `dw-verify` · `dw-risk`. The auditors diagnose (read-only); `dw-fix` is the one
  writer. Artifacts: `.ai/verify/<branch-slug>/`.
- **`dw-solo`** — the thin lane, for repos only you read. `dw-init` · `dw-grill` · `dw-shape` ·
  `dw-next` · `dw-land`. One `CHANGE.md` instead of spec+plan+notes, one `dw-land` pass instead of
  five auditors, and durable knowledge promoted out to `docs/decisions/` + `CONTEXT.md` + `CLAUDE.md`'s
  `## Gotchas` + `.ai/BACKLOG.md` (the follow-ups you're not doing now) rather than accumulated.
  Artifacts: `.ai/work/<slug>/`.

## ⚙ How it works — the design in one screen

Full design rationale — the _why_ behind each choice — lives in [`docs/DESIGN.md`](docs/DESIGN.md).

- **Persistence in the skill, not a wrapper.** Each `SKILL.md` writes its own `.ai/` paths as part of
  its procedure, so plans land automatically and travel with the installed plugin — no
  `.claude/commands/` glue layer. (Stack commands are read from your project too — nothing is
  hardcoded; that's the opening pitch up top.)
- **`.ai/` is tracked, one folder per task, no central index.** Artifacts are real work docs
  committed with the code; each run is matched to its git branch, so branches never fight over one file.
- **Thin harness, fat skills.** The process lives in the markdown, not in glue code — so every model
  upgrade improves the skills for free. Bulky detail (templates, examples) loads on demand from
  `references/`. (Inspired by ["Fat Skills"](https://x.com/garrytan/status/2042925773300908103).)
- **Composable, not chained.** Skills stay separate and link through shared `.ai/` artifacts + a
  "Next:" pointer — a recommendation, never a forced sequence. Why there's no autonomous loop closing
  this is in [`docs/DESIGN.md`](docs/DESIGN.md), "Loops vs persistence."
- **Two lanes, one toolbox.** How much process a change deserves depends on who reads the artifacts, so
  the same loop ships at two weights — `dw-planning` + `dw-quality` for shared repos, `dw-solo` for your
  own. They share the runtime scripts and the `templates/` canon; install one lane per repo.
- **Explicit-only skills** (`dw-bootstrap`, `dw-handoff`, `dw-init`, `dw-prune`, `dw-split`, `dw-sync`, `dw-setup-precommit`) are invoked by name and never auto-trigger; the rest can be model-invoked when the task fits.

## ▤ Project structure

```
skills/<name>/SKILL.md          canonical skill (edit here)
plugins/<collection>/           plugin.json + git-tracked symlinks → ../../../skills/<name>
scripts/runtime/                shipped scripts, symlinked into each consuming plugin
templates/                      shared template payload (hooks, settings.json, CLAUDE.local.md)
.claude-plugin/marketplace.json makes the repo installable
docs/WORKFLOWS.md               the guided tour (the "how" — recipes + decisions)
docs/DESIGN.md                  design rationale (the "why")
docs/SKILL-ANATOMY.md           the shape every SKILL.md follows
```

## ◈ Contributing

Layout, conventions, the add-a-skill checklist, and CI all live in [`AGENTS.md`](AGENTS.md)
(`CLAUDE.md` is a symlink to it).

## ▪ License

MIT
