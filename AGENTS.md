# dw-skills — agent instructions

A personal bucket of Claude Code skills, distributed as an installable plugin marketplace — not a
code project.

## Layout — and the one rule

```
skills/<name>/SKILL.md           the canon for every skill. EDIT HERE.
plugins/<plugin>/                plugin.json + git-tracked symlinks (mode 120000) → the canon
scripts/runtime/<script>.sh      shipped scripts — symlinked into each consuming plugin
scripts/<script>.sh              repo CI tooling, never shipped (validate-*.sh, lint.sh)
scripts/tests/<script>.test.sh   bash self-tests for scripts/runtime/
templates/                       payload copied verbatim INTO a target project (hooks, settings.json)
.claude-plugin/marketplace.json  makes this repo installable as a plugin source
```

**Always edit the canon above; use it instead of any `plugins/…` path**, since every one of those is
a symlink back to it — `plugins/*/skills/`, `plugins/*/scripts/` and `plugins/*/templates/` alike.

Skill bodies invoke a shipped script as `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh` — install
dereferences the symlink, so the path resolves. A script used by only **one** skill needs no canon:
bundle it in `skills/<name>/scripts/` and invoke it via `<this-skill-dir>/…`, as `dw-doctor` does.
Why it's built this way: [`docs/DESIGN.md`](docs/DESIGN.md), "The symlink canon".

**Two lanes.** `dw-planning` + `dw-quality` (team; `.ai/runs/` + `.ai/verify/`) · `dw-solo` (thin; one
`CHANGE.md` in `.ai/work/`) · `dw-misc` (both). A new skill picks one lane — say which in its
description, and keep lanes free of cross-dependencies. Why: [`docs/DESIGN.md`](docs/DESIGN.md).

## Adding a skill

1. `skills/<name>/SKILL.md` — kebab-case `name` matching the directory, a `description` that is
   routing signal only, `disable-model-invocation: true` if explicit-invoke only. Shape:
   [`docs/SKILL-ANATOMY.md`](docs/SKILL-ANATOMY.md); copy a near neighbour like `dw-handoff`.
2. `plugins/<plugin>/.claude-plugin/plugin.json`, then
   `ln -s ../../../skills/<name> plugins/<plugin>/skills/<name>` and `git add` the symlink.
3. Add the row to `.claude-plugin/marketplace.json` and bump the plugin's patch version in **both**
   that row and `plugins/<plugin>/.claude-plugin/plugin.json` — keep the two identical.
4. Name the skill everywhere the docs list skills: the README **Plugins** section, its
   **task-router** row, the **workflow diagram** if it joins the core loop, and — if explicit-invoke
   — the `⭑` marker plus the explicit-only lists in README **and** `docs/DESIGN.md`.
5. `pnpm lint && pnpm format && pnpm validate:manifests && pnpm validate:docs`.

Steps 3–4 are CI-enforced. The validators name the exact missing entry — run them rather than
re-deriving the checklist by hand.

## Adding a shipped (plugin-level) script

1. Put the real file once at `scripts/runtime/<script>.sh` and `chmod +x` it.
2. Per consuming plugin: `ln -s ../../../scripts/runtime/<script>.sh plugins/<plugin>/scripts/<script>.sh`
   and `git add` the symlink (must be mode 120000).
3. Add the basename to `RUNTIME_SCRIPTS` in `scripts/validate-manifests.sh`, plus a
   `scripts/tests/<script>.test.sh` where it has logic worth pinning (anchor it to the repo root via
   `git rev-parse --show-toplevel`, like `validate-ai-artifacts.test.sh`).

## Before you push

```bash
pnpm lint && pnpm format && pnpm validate:manifests && pnpm validate:artifacts && pnpm validate:docs
```

CI runs those five plus a `trufflehog` secrets scan on every PR and push to `main`. What each gate
checks: [`CONTRIBUTING.md`](CONTRIBUTING.md).
