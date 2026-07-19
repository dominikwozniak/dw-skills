---
name: dw-setup-precommit
description: >-
  Wire git-level pre-commit hooks for a pnpm node/ts/js repo — husky + lint-staged — so every
  `git commit` auto-formats and lints the staged files with the tools the project already has.
  Team-shared config committed to the repo (fires for every developer on commit), distinct from
  `.claude/hooks/*.sh` which only run inside a Claude session. pnpm-only. Explicit-invoke only. Use
  for "set up pre-commit", "add husky", "configure lint-staged", "format and lint on commit", or
  "dw-setup-precommit".
argument-hint: "optional: 'with-typecheck' / 'with-test' to add those hook steps"
disable-model-invocation: true
---

# dw-setup-precommit — wire git pre-commit hooks (husky + lint-staged)

Make `git commit` run the project's formatter and linter over just the staged
files, every time, for everyone. The point is to catch unformatted or
lint-failing code at the commit boundary rather than in CI — so the diff that
lands is already clean.

This is **git-level, team-shared config**: `.husky/pre-commit` and the
lint-staged map are committed to the repo and run on every contributor's machine
the moment they `git commit`. That is deliberately **distinct from
`.claude/hooks/*.sh`** — those only fire inside a Claude Code session and protect
the agent, not the team. A repo can have both; this skill installs the half that
guards everyone.

It is **opinionated by design**: pnpm only (never npx) and node/ts/js only. There
is no multi-package-manager detection — if the project isn't pnpm + node, the
skill stops rather than guess. It also never assumes a formatter, linter, or
their config files exist; it reads the project and wires only what's actually
there.

## What it writes

All of these are **tracked in git** — that's the whole point, they're shared with
the team. Nothing here is personal/ignored.

| Path                 | Purpose                                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `.husky/pre-commit`  | The hook git runs. Calls `pnpm exec lint-staged`; optionally `pnpm run typecheck` / `pnpm run test`. |
| `.lintstagedrc.json` | Glob → command map, in `pnpm exec` form, referencing only the tools detected in the project.         |
| `package.json`       | Adds `husky` + `lint-staged` devDeps and a `"prepare": "husky"` script; optional pnpm-enforcement.   |
| `.npmrc`             | _(optional, consent-gated)_ `engine-strict=true`, only if pnpm enforcement is chosen.                |

Re-running is safe: read what's already there first and only fill gaps — never
clobber an existing `.husky/pre-commit` or lint-staged config without showing the
diff at the step-3 gate.

## Workflow

### 1. Preflight & bail

Confirm the target is a pnpm node project before touching anything:

- `package.json` exists, **and**
- the project is pnpm — `pnpm-lock.yaml` is present **or** `package.json` has
  `"packageManager": "pnpm@…"`.

If either is missing, **HARD STOP**: say plainly this skill is pnpm + node/ts/js
only, name what's missing, and do nothing else. No npm/yarn/bun fallback, no
"I'll set up pnpm for you" — bailing is the correct outcome.

### 2. Detect existing tooling — never assume

Read `package.json` and grep the repo. Wire only what you can confirm is present:

- **Formatter** — prettier or biome (a dep, a `.prettierrc*` / `biome.json`, or a
  `format` script).
- **Linter** — eslint, biome, or oxlint (a dep + its config).
- **Scripts** — whether `typecheck` and `test` exist under `scripts`.

Ground every choice in something you actually found — a dep line, a config file, a
script entry. If **no formatter** exists, _offer_ to add prettier (consent-gated
in the next step); never add it silently. If neither a formatter nor a linter
exists and the user declines prettier, there's nothing to wire — say so and stop.

See `references/setup.md` for the detection signals and the glob→command mapping.

### 3. HARD STOP gate — shared config, ask first

Before installing anything, stop and lay out the plan for explicit consent.
State plainly: **this commits config that runs on every teammate's machine, not
just yours.** Show what will be installed, the exact `.husky/pre-commit` and
`.lintstagedrc.json` you'll write (from the detection in step 2), and wait.

In the same gate, ask the two opt-ins:

- Add `pnpm run typecheck` to the hook? Only offer if a `typecheck` script
  exists. **Warn it makes commits slower** (whole-project typecheck on every
  commit).
- Add `pnpm run test`? Only offer if a `test` script exists. Same slowness
  warning — often better left to CI.

Wire each optional step only if its script exists **and** the dev opts in.

### 4. Install

```
pnpm add -D husky lint-staged
```

Add `prettier` to that list **only** if the user chose it in step 2. Never
`npm`/`yarn`/`bun`, never `npx`.

### 5. Init husky

```
pnpm dlx husky init
```

Ensure `package.json` has `"prepare": "husky"` (husky's init adds it; confirm it's
there). On husky v9+, hook files are plain shell — **no shebang needed**.

### 6. Write `.husky/pre-commit`

Start from `references/pre-commit`. The required line is:

```
pnpm exec lint-staged
```

Append `pnpm run typecheck` and/or `pnpm run test` lines **only** for the opt-ins
confirmed in step 3 (script exists + dev agreed).

### 7. Write the lint-staged config

Write `.lintstagedrc.json` (start from `references/lintstagedrc.json`), mapping
globs to the **detected** commands in `pnpm exec` form — e.g. prettier
`--write`, eslint `--fix`. Reference only tools confirmed in step 2; do not add an
eslint or prettier entry unless that tool and its config actually exist. (A
`lint-staged` key in `package.json` is an equally valid home — prefer the
standalone file for a clean diff unless the project already centralizes config in
`package.json`.)

### 8. Optional pnpm enforcement (consent-gated)

Offer — don't impose — the git-level twin of this repo's `block-non-pnpm` Claude
hook, so a teammate can't quietly use npm/yarn:

- `"preinstall": "pnpm dlx only-allow pnpm"` in `package.json`,
- `engine-strict=true` in `.npmrc`,
- a corepack `"packageManager": "pnpm@<version>"` field.

Add only what the user accepts.

### 9. Smoke test

Confirm the hook actually fires without making a real commit:

```
pnpm exec lint-staged --diff
```

(or a dry run over staged files). Surface the result. **Do not create a real
commit** unless the user explicitly asks — leaving the first commit to them keeps
this skill side-effect-honest.

### 10. Report

Summarize what changed: packages installed, files written, which optional steps
were wired and which were skipped (and why). Be specific — the dev needs to know
exactly what their teammates will inherit.

## Guardrails

- **pnpm only, never npx.** Every command is `pnpm add -D` / `pnpm dlx` /
  `pnpm exec`. `npx` appears nowhere — not in the skill, not in the files it
  writes.
- **node/ts/js only.** No `package.json` + pnpm → HARD STOP (step 1). No
  multi-package-manager detection on purpose.
- **Ground every claim.** Confirm each formatter/linter/script via Read/grep
  before wiring it. Never assume an eslint or prettier config exists.
- **Read the project, don't hardcode.** The lint-staged commands come from what
  the repo actually has, not a fixed template.
- **HARD STOP before install.** This is shared config affecting every teammate
  (step 3) — explicit consent first, always.
- **Always report what it did.** End with the exact list of changes (step 10).

## References

- `references/pre-commit` — sample `.husky/pre-commit` to start from (husky v9+,
  no shebang; the optional typecheck/test lines shown commented).
- `references/lintstagedrc.json` — sample lint-staged map in `pnpm exec` form.
- `references/setup.md` — detection signals, the glob→command mapping table, the
  consent question bank, and idempotent re-run rules. Read when detecting tooling
  (step 2) or re-running on a repo that's partly set up.

**Next:** `dw-git` to make the first commit now that the hook is live — it'll run
through `.husky/pre-commit` on the way in.
$ARGUMENTS
