---
name: dw-init
description: >-
  Scaffold a private/solo repo for the `dw-grill → dw-shape → dw-next → dw-land` loop —
  `.ai/work/`, `docs/decisions/`, `CONTEXT.md`, a `## Gotchas` section in `CLAUDE.md`, and the
  guardrail hooks. Deliberately smaller than `dw-bootstrap`, which is the one for a shared/team
  repo. Explicit-invoke only. Use when setting up one of your own projects for the solo lane, or
  when someone says "init this project", "set up the solo loop".
argument-hint: "any project context to seed (stack, what it is)"
disable-model-invocation: true
---

# dw-init — scaffold a repo for the solo lane

The setup step for **your own** projects. Where `dw-bootstrap` scaffolds a repo other people will
read — tracked specs, verification artifacts, handoffs — this one scaffolds a repo where you are the
only reader, and drops everything that only pays off with an audience.

It is a separate skill rather than a mode of `dw-bootstrap` on purpose: the two lanes want different
directories and a different `CLAUDE.local.md`, and a mode flag would put a branch on every step of
both.

## What it writes

| Path                    | Tracked?           | Purpose                                                      |
| ----------------------- | ------------------ | ------------------------------------------------------------ |
| `.ai/work/`             | **tracked**        | one folder per change (`dw-shape` writes `CHANGE.md`)        |
| `.ai/README.md`         | **tracked**        | three lines saying what `.ai/` is and who owns it            |
| `docs/decisions/`       | **tracked**        | durable decision records (`dw-land` promotes here)           |
| `CONTEXT.md`            | **tracked**        | the project's glossary — terms only                          |
| `CLAUDE.md`             | **tracked**        | a `## Gotchas` section — `dw-land` appends to it             |
| `.claude/settings.json` | **tracked**        | permissions (ask + deny + derived allow), hooks, lane switch |
| `.claude/hooks/*.sh`    | **tracked**        | the guardrail scripts those settings reference               |
| `CLAUDE.local.md`       | personal / ignored | your commands, git conventions, and the loop                 |
| `.gitignore`            | tracked            | a managed marker block for the personal files                |

Note what is **absent** versus `dw-bootstrap`: no `.ai/verify/`, no `.ai/handoffs/`. The solo lane has
one quality pass that writes no artifact, and no one to hand off to.

Templates come from `${CLAUDE_PLUGIN_ROOT}/templates/` — the shared canon, so the guardrail hooks are
byte-identical to the team lane's. (`${CLAUDE_PLUGIN_ROOT}` is the env var Claude Code substitutes to
this plugin's install dir.)

## Workflow

### 1. Detect — never assume the stack

- Repo root (`git rev-parse --show-toplevel`) and default branch
  (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `init.defaultBranch`, else `main`).
- Test / lint / typecheck commands from the manifests actually present — `package.json` scripts,
  `Gemfile` + `bin/`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`. Read the real commands;
  don't invent them. **Keep this list** — it becomes the `permissions.allow` entries in step 4, and a
  command you didn't find here must not appear there.
- What already exists: `CLAUDE.md`, `CLAUDE.local.md`, `.claude/settings*`, `.gitignore`, `CONTEXT.md`,
  `docs/`. This is rarely a greenfield tree, and step 3 must diff against reality.

### 2. Pick the hooks

Two are always offered because they're pure guardrails: `block-dangerous-commands` and
`block-env-access`. Add the stack-specific ones only where the stack is actually present —
`block-non-pnpm`, `lint-on-edit`, `typecheck-on-stop` for JS/TS, `lint-on-edit-rb` for Ruby. On a
stack with no lint or typecheck hook, offer the two guards alone and say the rest are stack-specific
rather than silently writing nothing.

### 3. HARD STOP — show what you're about to write

List every path, marked **tracked** or **ignored**, with a diff for anything that already exists. Add two
things that aren't paths: **the `permissions.allow` list you derived in step 1**, so what the agent may
run without asking is approved rather than assumed, and **the team-lane plugins you're about to disable
for this repo**, since that changes which skills exist here. **Wait for explicit confirmation.**
Scaffolding mutates the repo and a wrong clobber is expensive — this gate is not optional even though the
rest of the lane is light.

### 4. Write

- `mkdir -p .ai/work docs/decisions` and seed each with `.gitkeep`.
- `.ai/README.md` — write it inline, three or four lines: `.ai/work/<slug>/CHANGE.md` is the live
  working state for one change, it is tracked so it survives a `/clear`, and `dw-land` deletes it at
  merge after promoting anything durable to `docs/decisions/`, `CONTEXT.md` and `CLAUDE.md`. Don't copy the team
  lane's `templates/ai-README.md` — it documents directories this lane doesn't have.
- `CONTEXT.md` — if absent, create it with a one-line purpose statement (this project's glossary;
  terms only, no implementation detail) and nothing else. If it exists, leave it alone.
- `${CLAUDE_PLUGIN_ROOT}/templates/settings.json` → `.claude/settings.json`; **prune** the hook
  entries not selected, add the `permissions.allow` list (below), then confirm the file still parses as
  valid JSON.
- `CLAUDE.md` — seed a `## Gotchas` section: one line of purpose (traps this project has actually
  sprung, newest first) and nothing else. Create the file with just that section if it's absent; append
  the section if the file exists without one; leave it alone if it's already there. It goes in tracked
  `CLAUDE.md` rather than `CLAUDE.local.md` because it has to be **auto-loaded** (so the next session
  actually reads it), **tracked** (so it outlives the machine), and in **one** place. `dw-land`
  appends to it.
- The selected `${CLAUDE_PLUGIN_ROOT}/templates/hooks/*.sh` → `.claude/hooks/`, `chmod +x` each.
- `CLAUDE.local.md` — if absent, render `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.local.md` and
  substitute `{{PROJECT_NAME}}` `{{DEFAULT_BRANCH}}` `{{STACK}}` `{{TEST_COMMAND}}`
  `{{LINT_COMMAND}}` `{{TYPECHECK_COMMAND}}` `{{HOOKS_INSTALLED}}`. Either way, **replace its
  `## Workflow` section** with the solo loop (below) — the template ships the team loop.
- Append `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-block.txt` to `.gitignore` between its markers.
  **Idempotent**: if the markers are already there, replace the block in place, never duplicate it.
- **Switch the lane off for the team plugins** — after `.claude/settings.json` exists, run
  `claude plugin disable dw-planning --scope project` and `claude plugin disable dw-quality --scope project`.
  Then confirm the file still parses as valid JSON: the CLI rewrites it (it also reorders the
  `permissions` keys), so re-check rather than assume.

**The `permissions.allow` list — derived, never invented.** The template ships `ask` and `deny` only,
so nothing is pre-approved and every check waits on a prompt unless a global setting happens to cover
it. This is the difference between a lane that runs and one that idles, so build the list from what
step 1 actually found:

- **The project's own checks, exactly as detected.** Match the wildcard style already used in the
  template's `ask` list — a bare entry plus an argument form, e.g. `Bash(pnpm test)` and
  `Bash(pnpm test *)`. **Never allowlist a script that isn't in the manifest**: an entry for a command
  that doesn't exist is worse than no entry, because it reads as verified.
- **The read-only git surface every skill in this lane uses** — `git status`, `git diff`, `git log`,
  `git branch --show-current`, `git rev-parse`, `git symbolic-ref`, in the same two forms.

**Write nothing that overlaps `ask` or `deny`.** Don't reason about which list wins — just never add an
entry that could match `git commit`, `git push`, anything in the template's `ask` list, or anything
touching `.env`. Adding write or network commands here is not a speed optimisation; it removes the gate
the rest of the lane is built around.

**The lane switch — use the CLI, never hand-write the key.** `claude plugin disable dw-planning --scope
project` adds an `enabledPlugins` entry to `.claude/settings.json`, keyed `dw-planning@` plus the
marketplace id and set to `false` — **with the correct id filled in for you**. Write that key by hand and
you have to know the id, and a wrong one is **silently ignored**: no error, no warning, the team lane
simply stays on. The CLI is the only way to get it right without guessing, so use it even though the
result is only two lines of JSON.

Two consequences worth stating: it only works for a plugin that is actually **installed** here — if
neither team plugin is, there is nothing to disable, so skip it and say so rather than treating the
failure as an error. And it **only ever disables**: never run `claude plugin enable` from this skill.
Enabling is an install-time decision, and a scaffolder that switches plugins on is one that can
surprise you.

The `## Workflow` block to write:

```markdown
## Workflow

- Loop: `/dw-shape → /dw-next`, then `/dw-land` before the PR. `/dw-grill` first when the idea is fuzzy.
- One change at a time lives in `.ai/work/<slug>/CHANGE.md` — tracked, and deleted by `/dw-land` at merge.
- `/dw-next` bare answers "where were we" from disk; `/dw-next go` builds the next task.
- Durable knowledge is promoted out, not accumulated: decisions → `docs/decisions/`, terms → `CONTEXT.md`.
```

### 5. Reconcile tracking

The split is the whole point, so enforce it after writing: `.ai/`, `docs/decisions/`, `CONTEXT.md`,
`CLAUDE.md`, `.claude/settings.json` and `.claude/hooks/` must **not** be ignored — remove any
pre-existing rule that ignores them. `CLAUDE.local.md` and `.claude/settings.local.json` must **be**
ignored.

### 6. Report

List what was written and which paths to `git add`, and name the team-lane plugins now disabled for this
repo — running both lanes in one project is what makes two skills compete for the same request, and the
scaffold has just settled it. If a disable didn't apply (the plugin wasn't installed, or the command
failed), say that plainly instead of reporting a lane switch that isn't there.

**Next:** `dw-shape` to open the first change, or `dw-git` to commit the scaffold.

$ARGUMENTS
