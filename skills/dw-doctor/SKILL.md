---
name: dw-doctor
description: >-
  Diagnose a dw-* repo without changing it: shared memory, Claude/Codex hook wiring, plugin state,
  required tools, legacy files, and known guardrail limitations. Reports observed gaps and fixes.
  Use for "check my setup", "why aren't hooks running", "diagnose the repo", or "dw-doctor".
argument-hint: "[--platform auto|claude|codex|both]"
---

# dw-doctor — read-only environment diagnostic

Use expanded invocation arguments when available. If the host leaves literal `$ARGUMENTS`, ignore
the placeholder and infer the platform from the active host or the user's prompt.

Confirm the machine actually has what this repo's hooks and skills assume, and
that the wiring resolves — before a missing tool silently degrades things. The
sharpest case: every generated hook script opens with
`command -v jq >/dev/null || exit 0`, so on a box without `jq` the
dangerous-command block, `.env` protection, pnpm enforcement, and
lint/typecheck-on-edit hooks **all quietly no-op** and nobody notices. Same failure class for a missing `pnpm`, a
`settings.json` pointing at a hook that isn't executable, or a typecheck hook
with no `tsc` to call.

**Read-only:** it probes (`command -v`, `--version`) and reads files, then
reports. It never installs a tool, never edits a file, never runs the fixes it
suggests — applying them is your call.

## What it reads

It diagnoses the **current git repo** (resolved via `git rev-parse
--show-toplevel`), not the skill's own location. Checks are conditional on what
the repo declares, so nothing about a stack is assumed:

- `package.json` — `engines.node`, `packageManager`, declared deps, and
  `scripts.typecheck` (drives the JS/TS checks).
- `Gemfile` — whether `standard` / `rubocop` is declared (drives the Ruby checks).
- `tsconfig.json`, `.nvmrc` — presence informs the `tsc` / node checks.
- `.claude/settings.json` and `.codex/hooks.json` — parsed for wired hook commands; each referenced
  `*.sh` is checked for existence + the executable bit.
- `.ai/`, `AGENTS.md`, `DW.local.md`, and legacy Claude files — shared state, precedence, and
  migration diagnostics.
- `codex plugin list --json` — exact `dw-skills@dw-skills` installed/enabled/version state and its
  cache (17 skills, 5 explicit-only policies, executable runtime helpers).
- `claude plugin list --json` — the three exact `*@dw-skills` packages, their `installPath`, skill
  counts, and `scripts/runtime` payload.
- `.claude-plugin/marketplace.json` — only if present (a marketplace repo); a
  light plugin/version-sync glance.
- Tool presence on `PATH` via `command -v`: `git`, `jq`, `gh`, `node`, `pnpm`,
  `bundle`, and the project-local `agnix` / `prettier` / `tsc` binaries.

## Workflow

### 1. Run the bundled script

From anywhere inside the target repo, run the script shipped with this skill:

```
bash "<this-skill-dir>/scripts/doctor.sh" --platform auto
```

`<this-skill-dir>` is the directory holding this `SKILL.md` (e.g.
`skills/dw-doctor` in source, or the installed plugin's `skills/dw-doctor`). The
script resolves the repo itself, so the working directory only needs to be
somewhere inside the repo you want diagnosed.

Accepted platforms are `auto`, `claude`, `codex`, and `both`. In Codex mode, always surface that
`.env` protection is best-effort because not every built-in read is hookable.

### 2. Relay the report

The script prints grouped `OK` / `WARN` / `FAIL` lines with a one-line fix on
each non-OK. Summarize it for the user and **lead with any `FAIL`** — especially
`jq` or `git`, since those gate everything else. Surface the install commands it
prints (e.g. `brew install jq`, `corepack enable`, `pnpm install`) verbatim so
they can copy-paste, but do not run them yourself.

### 3. Stop

Report and hand off. Fixing the environment is the user's action; `dw-doctor`
only diagnoses.

**Next:** if the report flagged a missing scaffold (no `.ai/`, no hooks), run
`dw-bootstrap` to lay it down; if the environment is clean, `dw-spec` to open the
first run (or `dw-resume` if one already exists).

## Guardrails

- **Read-only.** Never install a tool, edit a file, or run a suggested fix. The
  script only probes and reads, including the two hosts' read-only `plugin list --json` commands.
- **Stack-adaptive.** JS/TS checks run only when `package.json` exists; Ruby
  checks only when `Gemfile` exists; `tsc` only when the repo asks for
  typechecking. It reports what's declared, never a hardcoded stack.
- **Consumer-first.** It diagnoses the current git repo, not the skill's
  location, so it works the same in any repo bootstrapped onto the dw-\* loop. The
  marketplace/plugin check only fires when `marketplace.json` is present.
- **Never guesses.** It reports observed state and the consequence of each gap;
  it doesn't infer intent or "fix" anything for you.
