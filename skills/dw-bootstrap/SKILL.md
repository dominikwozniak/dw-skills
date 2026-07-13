---
name: dw-bootstrap
description: >-
  Scaffold a repo for dw-* on Claude Code, Codex, or both: shared AGENTS.md and .ai/ memory,
  private DW.local.md, host hook adapters, and a managed .gitignore block. Supports skeleton and
  tuned modes. Use for "set up this project", "bootstrap codex", "bootstrap claude", or "dw-bootstrap".
argument-hint: "[skeleton|tuned] [--platform auto|claude|codex|both]"
disable-model-invocation: true
---

# dw-bootstrap — scaffold dw-\* for Codex, Claude, or both

Use expanded invocation arguments when available. If the host leaves literal `$ARGUMENTS`, ignore
the placeholder and infer mode, platform, and scope from the user's prompt.

Public interface: `dw-bootstrap [skeleton|tuned] [--platform auto|claude|codex|both]`.
`auto` selects the active host; ask when ambiguous. `both` is explicit only. The shared source is
tracked `AGENTS.md` plus ignored `DW.local.md`; host files are thin adapters.

The stance is deliberate: dw-\* treats agent infra as **real work** — specs,
plans, handoffs, and guardrails are committed and travel with the repo, not
thrown away.

## What it writes

| Path                                      | Tracked?           | Purpose                                                                 |
| ----------------------------------------- | ------------------ | ----------------------------------------------------------------------- |
| `.ai/runs/` `.ai/handoffs/` `.ai/verify/` | **tracked**        | memory the dw-\* skills read/write (`.gitkeep` seeds empty dirs)        |
| `.ai/README.md`                           | **tracked**        | self-documents the `.ai/` layout for teammates + non-Claude tools       |
| `AGENTS.md`                               | **tracked**        | shared commands, architecture, conventions, and dw-\* workflow          |
| `DW.local.md`                             | personal / ignored | private profile, tools, URLs, and machine-specific overrides            |
| `.claude/settings.json`, `.claude/hooks/` | **tracked**        | Claude adapter, only for `claude` or `both`                             |
| `CLAUDE.md`, `CLAUDE.local.md`            | tracked / ignored  | thin imports of `AGENTS.md` and `DW.local.md`                           |
| `.codex/hooks.json`, `.codex/hooks/`      | **tracked**        | Codex adapter, only for `codex` or `both`                               |
| `.claude/settings.local.json`             | personal / ignored | personal-only setting overrides (only if you add one)                   |
| `.gitignore`                              | tracked            | a managed marker block — ignores the two personal files, **not** `.ai/` |

`.ai/` is tracked in git on purpose. Never overwrite a file blind — read what's
there first (step 1) and present a diff before writing (step 4).

## Modes

- **A · skeleton** — lay down the structure from templates with placeholders left
  in. Auto-detect stack + commands, pick hooks, write. Fast; you fill the prose
  later.
- **B · tuned** — skeleton, then **interview** the user and fill `AGENTS.md` / `DW.local.md`
  for this project and these preferences (the rich shape: About-me, stack
  cheat-sheet, git conventions, project specifics). This is the "pod siebie" mode
  and the main reason this is a skill, not a `sed` script.

## Workflow

### 1. Detect — never assume the stack

- Repo root (`git rev-parse --show-toplevel`), default branch
  (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `init.defaultBranch`,
  else `main`).
- Stack + commands from manifests — `package.json` scripts, `Gemfile`,
  `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`. Read the real test / lint
  / typecheck commands; don't invent them.
- Read what already exists — `AGENTS.md`, `AGENTS.override.md`, `DW.local.md`, `CLAUDE.md`,
  `CLAUDE.local.md`, `.claude/settings*`, `.codex/hooks*`,
  `.gitignore` — so step 4 diffs against reality and step 6 doesn't clobber or
  double-write a managed block. Don't assume a greenfield tree.

### 2. Pick mode + features — ask through the host's user-input mechanism

- Mode **A skeleton** vs **B tuned**.
- Platform `auto | claude | codex | both`, then features: shared `.ai/`, `AGENTS.md`,
  `DW.local.md`, `.gitignore`, and only the chosen host adapter(s).
- Hooks, filtered by detected stack: `block-dangerous-commands` + `block-env-access`
  (always), `block-non-pnpm` + `lint-on-edit` + `typecheck-on-stop` (JS/TS),
  `lint-on-edit-rb` (Ruby). On stacks with no lint/typecheck hook, offer the two
  always-on guards alone and note the rest are stack-specific (see
  `references/bootstrap.md` → _Stack → hooks_).

### 3. (Mode B only) Interview — fill the prose

Walk the question bank in `references/bootstrap.md` → _Interview_. Cover
About-me / preferences, project specifics, and git conventions. Keep it short —
ask, don't lecture; skip anything the user waves off.

### 4. HARD STOP — preview the plan and wait

If root `AGENTS.override.md` exists, stop first and ask which file owns shared instructions; it
masks `AGENTS.md`. List every path you're about to write, marked **tracked** or **ignored**, and for
any file that already exists show a diff (or "merge managed block only"). **Stop
and get explicit confirmation before writing.** Bootstrapping mutates the repo —
a wrong clobber is expensive. Do not write before the user confirms.

### 5. Write

- `mkdir -p .ai/{runs,handoffs,verify}` and seed each with `.gitkeep`. Copy
  `references/templates/ai-README.md` → `.ai/README.md` (static — no substitution).
- Render `references/templates/AGENTS.md` and `DW.local.md`. For Claude, install thin imports from
  `CLAUDE.md` / `CLAUDE.local.md`, settings, and hooks. For Codex, install `codex-hooks.json` as
  `.codex/hooks.json` — **prune** the hook entries whose scripts the user didn't select (the
  template wires every script), then confirm the file still parses as valid JSON — and the same
  selected scripts under `.codex/hooks/`; do not create `.codex/config.toml`. A wired script that
  is never copied errors on every matching Codex event. If an existing config explicitly disables
  hooks, show that conflict.
- Copy `references/templates/settings.json` → `.claude/settings.json`; **prune**
  the hook entries the user didn't select, then confirm the file still parses as
  valid JSON.
- Copy `references/templates/hooks/hook-common.sh` plus the selected hook scripts to each chosen
  host's hook directory, and `chmod +x` each. `hook-common.sh` is a sourced library and must not be
  wired as a hook. Automatic runtime commands may come only from ignored `DW.local.md`, then legacy
  `CLAUDE.local.md`; tracked `AGENTS.md` and `CLAUDE.md` are never execution sources. Local commands
  are whitespace-delimited argv lists without shell syntax; detected fallbacks are fixed argv arrays.
- Render the shared templates: substitute
  `{{PROJECT_NAME}}` `{{DEFAULT_BRANCH}}` `{{STACK}}` `{{TEST_COMMAND}}`
  `{{LINT_COMMAND}}` `{{TYPECHECK_COMMAND}}`, and build `{{HOOKS_INSTALLED}}` from
  the selected hooks. In tuned mode, put shared specifics in `AGENTS.md` and personal answers in
  `DW.local.md`.
- Append `references/templates/gitignore-block.txt` to `.gitignore`, fenced by
  its `>>> dw-bootstrap managed block >>>` markers. **Idempotent**: if the markers
  are already present, replace the block in place — never duplicate it.

### 6. Reconcile tracking

The split is the whole point — enforce it after writing:

- Ensure `.ai/`, `.claude/settings.json`, `.claude/hooks/` are **not** ignored. If
  a pre-existing rule ignores any of them, remove it.
- Ensure `DW.local.md`, `CLAUDE.local.md`, and `.claude/settings.local.json` **are** ignored.

### Legacy migration

When a populated `CLAUDE.local.md` exists without `DW.local.md`, propose copying its content into
`DW.local.md`. After verification, replace it with `@DW.local.md` only with explicit consent. On
refusal preserve both and warn that two sources remain. Never silently overwrite existing
instructions, settings, or hooks: update a marked block or show a diff.

### 7. Report + hand off

List what was written and which paths to `git add` (the tracked ones). Confirm the
hooks are wired by pointing at `.claude/settings.json`. Then point the user at the
loop.

**Next:** `dw-spec` to open the first run for a feature, or `dw-git` to commit the
scaffold.

## Templates

`references/templates/` holds the exact files to copy:

- `AGENTS.md` and `DW.local.md` — shared and private instruction templates.
- `CLAUDE.md` and `CLAUDE.local.md` — thin Claude import adapters.
- `codex-hooks.json` — tracked Codex hook adapter (prune unselected hooks).
- `ai-README.md` — the static `.ai/` layout doc, copied verbatim to `.ai/README.md`.
- `settings.json` — tracked permissions + hooks (prune unselected hooks).
- `gitignore-block.txt` — the marker-fenced managed block.
- `hooks/hook-common.sh` (sourced helper) · `hooks/block-dangerous-commands.sh` · `hooks/block-env-access.sh` ·
  `hooks/block-non-pnpm.sh` · `hooks/lint-on-edit.sh` · `hooks/lint-on-edit-rb.sh` ·
  `hooks/typecheck-on-stop.sh`.

## References

- `references/bootstrap.md` — the interview question bank, the tracked-vs-ignored
  rationale, the stack→hooks table, and idempotent re-run rules. Read it before
  running Mode B.

$ARGUMENTS
