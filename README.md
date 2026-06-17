# 🧩 dominikwozniak-skills

**A persistent, technology-agnostic spec → plan → build → verify workflow for Claude Code — as
installable skills.**

Plans and reviews land on disk under `.ai/` (tracked in git), so work survives a `/clear`, a new
session, or a handoff to another agent. Every skill reads your project's own commands and
conventions — nothing about a stack is baked in.

## 🚀 Quick start

```
claude plugin marketplace add git@github.com:dominikwozniak/dominikwozniak-skills.git
claude plugin install dw-planning   # spec → plan → build → resume → sync
claude plugin install dw-quality    # review · conform · prune · explain · verify · risk
claude plugin install dw-misc       # session handoff (+ future cross-cutting helpers)
```

Then start a feature: `/dw-spec`. Resume after a `/clear`: `/dw-resume`.

## 🔁 The workflow

```
  SPEC         PLAN         BUILD                   REVIEW · VERIFY           SHIP
  /dw-spec  →  /dw-plan  →  /dw-build       →       /dw-review  /dw-explain → (open PR)
                          ↺ /dw-resume (pick up)    /dw-conform /dw-verify
                            /dw-sync (fix drift)    /dw-prune   /dw-risk
  └────────────── .ai/runs/<id>/ ──────────────┘    └─ .ai/verify/<branch>/ ─┘

  /dw-handoff — compact context for the next agent, at any point.
```

A recommendation, not a rail: every skill stands alone and is invoked when you need it. They
compose through the shared `.ai/` artifacts + a "Next:" pointer at the end of each skill.

## 🧭 Task router — which skill for which task

A task may match several rows — read all that apply.

| Task                                                        | Skill                                      | What you get                           |
| ----------------------------------------------------------- | ------------------------------------------ | -------------------------------------- |
| **Spec & plan**                                             |                                            |                                        |
| Start a feature; capture intent with an open-questions gate | [`dw-spec`](skills/dw-spec/SKILL.md)       | `SPEC.md` under `.ai/runs/`            |
| Pick up after a `/clear`; find the first not-done step      | [`dw-resume`](skills/dw-resume/SKILL.md)   | read-only status report                |
| Turn a ready spec into thin vertical slices                 | [`dw-plan`](skills/dw-plan/SKILL.md)       | `PLAN.md` status table                 |
| **Build**                                                   |                                            |                                        |
| Build the next slice: RED → GREEN → regression → commit     | [`dw-build`](skills/dw-build/SKILL.md)     | code + `done` row + SHA                |
| Re-align the plan with the code after drift                 | [`dw-sync`](skills/dw-sync/SKILL.md)       | reconciled `PLAN.md` (consent-gated)   |
| **Review & verify**                                         |                                            |                                        |
| Multi-axis review of a diff (correctness/security/perf/…)   | [`dw-review`](skills/dw-review/SKILL.md)   | `review.md` + verdict                  |
| Check a change against the repo's existing patterns         | [`dw-conform`](skills/dw-conform/SKILL.md) | `conform.md` drift report              |
| Trim redundant tests without dropping coverage              | [`dw-prune`](skills/dw-prune/SKILL.md)     | keep/merge/delete plan (consent-gated) |
| Explain a change + generate runnable verification scenarios | [`dw-explain`](skills/dw-explain/SKILL.md) | `explain.md` scenarios                 |
| Run those scenarios and record PASS/FAIL + evidence         | [`dw-verify`](skills/dw-verify/SKILL.md)   | `verify-run.md`                        |
| Assess blast radius, out-of-code impact, rollback           | [`dw-risk`](skills/dw-risk/SKILL.md)       | `risk.md`                              |
| **Handoff**                                                 |                                            |                                        |
| Compact the session for the next agent                      | [`dw-handoff`](skills/dw-handoff/SKILL.md) | `.ai/handoffs/<ts>.md`                 |

## 📦 Plugins (install what you need)

- **`dw-planning`** — `dw-spec` · `dw-resume` · `dw-plan` · `dw-build` · `dw-sync`. The persistent
  spec→plan→build loop; artifacts under `.ai/runs/<id>/`.
- **`dw-quality`** — `dw-review` · `dw-conform` · `dw-prune` · `dw-explain` · `dw-verify` ·
  `dw-risk`. A change-quality pipeline writing to `.ai/verify/<branch>/`.
- **`dw-misc`** — `dw-handoff`, plus a bucket for future cross-cutting helpers.

## 🛠️ How it works

- **Persistence in the skill, not a wrapper.** Each `SKILL.md` bakes its `.ai/` paths in, so plans
  land automatically and travel with the installed plugin — no `.claude/commands/` glue.
- **`.ai/` is tracked, one folder per task, no central index.** Artifacts are real work docs
  committed with the code; runs are matched to the current git branch (no merge-conflict magnet).
- **Technology-agnostic.** Skills are pure procedures; test/lint/run commands and the commit
  convention are read _from the project_ (a declared `## Commands` block → manifests → the code),
  never hardcoded.
- **Thin harness, fat skills.** A skill's weight tracks its procedure; bulky detail (templates,
  taxonomies, stack examples) lives in `references/`, loaded on demand.
- **Composable, not chained.** Skills stay separate (different axes) and link through shared `.ai/`
  artifacts + a "Next:" pointer — a recommendation, never a forced sequence.
- **Explicit-only skills** (`dw-handoff`, `dw-prune`, `dw-sync`) are invoked by name and never
  auto-trigger; the rest can be model-invoked when the task fits.

Full design rationale — the _why_ behind each choice — lives in [`docs/DESIGN.md`](docs/DESIGN.md).

## 📁 Project structure

```
skills/<name>/SKILL.md          canonical skill (edit here)
plugins/<collection>/           plugin.json + git-tracked symlinks → ../../../skills/<name>
.claude-plugin/marketplace.json makes the repo installable
docs/DESIGN.md                  design rationale (the "why")
```

## 🤝 Contributing

Layout, conventions, the add-a-skill checklist, and CI all live in [`AGENTS.md`](AGENTS.md)
(`CLAUDE.md` is a symlink to it).

## 📜 License

MIT
