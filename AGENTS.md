# dw-skills — agent instructions

Portable Codex and Claude Code skills, distributed as installable plugin marketplaces.

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`.codex-plugin/plugin.json`** — aggregate Codex plugin exposing all real root `skills/` and
  `scripts/runtime/` payload; never add symlinks to the Codex payload.
- **`.agents/plugins/marketplace.json`** — Codex marketplace with one `dw-skills` entry.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` and shipped `scripts/runtime/<script>.sh` are **git-tracked symlinks** (mode 120000)
  → the repo-root canon — `../../../skills/<name>` and `../../../../scripts/runtime/<script>.sh` — plus
  `plugins/<name>/.claude-plugin/plugin.json`. `claude plugin install` **dereferences** these
  symlinks: each plugin gets its own real copy in the plugin cache (verified — the installed cache
  contains 0 symlinks), so a script is invoked from the installed skill via its unchanged relative
  `../../scripts/runtime/<script>.sh`. Because install dereferences, one canonical script
  can be symlinked into several plugins (e.g. `slugify.sh` into both `dw-planning` and `dw-quality`)
  with no duplication. (A script used by **one** skill instead stays bundled in that skill:
  `skills/<name>/scripts/` invoked via `<this-skill-dir>/…`, e.g. `dw-doctor`.)
- **`scripts/`** — repo home for shell scripts, split by purpose:
  - **`scripts/runtime/`** — canonical home for every **plugin-level shipped** script (resolved by a
    skill as absolute `<this-skill-dir>/../../scripts/runtime/<script>.sh`); symlinked into each
    consuming `plugins/<name>/scripts/runtime/` for Claude and shipped directly by the root Codex plugin.
  - **`scripts/`** (top level) — repo CI/validation tooling, never shipped (e.g.
    `validate-manifests.sh` / `validate-artifacts.sh` backing `pnpm validate:*`, `lint.sh`).
  - **`scripts/tests/`** — bash self-tests for the runtime scripts (`<script>.sh` ↔
    `<script>.test.sh`), run via `pnpm validate:artifacts`.
- **`.claude-plugin/marketplace.json`** — Claude marketplace with three selective packages.

## Conventions

- Skills use YAML frontmatter; `disable-model-invocation: true` for explicit-invoke-only skills.
- Skill name: kebab-case, matches the directory name.
- Canonical file is `skills/<name>/SKILL.md` — edit there, never via the plugin symlink.
- `package.json.version` is canonical and must match both marketplaces and all four manifests.
- Explicit-only skills need both Claude frontmatter and Codex `agents/openai.yaml` policy.
- Descriptions are ≤350 characters each and ≤6000 total.
- Codex CLI 0.142.0 is the minimum supported installer; `latest` is an informational CI row.

## When adding a new skill

1. Create `skills/<name>/SKILL.md` (kebab-case `name`, `description` with trigger phrases),
   following the shape in [`docs/SKILL-ANATOMY.md`](docs/SKILL-ANATOMY.md).
2. Choose one existing Claude collection (`dw-misc`, `dw-planning`, or `dw-quality`), then add
   `plugins/<collection>/skills/<name>` as a tracked symlink to `../../../skills/<name>`. Do not
   create a fourth Claude package unless the distribution design changes explicitly.
3. The root Codex plugin discovers the real `skills/<name>` automatically; no Codex symlink or
   per-skill marketplace entry is needed.
4. Bump `package.json.version`, all three Claude manifests, the Claude marketplace metadata and
   entries, and `.codex-plugin/plugin.json` together. The package version is canonical.
5. Update the docs that name skills — more than just the README Plugins + task-router. Grep the
   skill name across `README.md` and `docs/` to catch every hit; the usual ones:
   - README **Plugins** section and **task-router table** row (trigger phrase + output shape).
   - README **workflow diagram** if the skill joins the core spec→ship loop, and the **Quick
     start** install-comment if a plugin's skill list changes.
   - If explicit-invoke (`disable-model-invocation: true`): the `⭑` in the task-router table, plus
     the explicit-only lists in README **How it works**, `docs/DESIGN.md`, `docs/WORKFLOWS.md`, and
     `docs/SKILL-ANATOMY.md`. `pnpm validate:docs` enforces the complete set.
6. Run `pnpm lint`, `pnpm format`, `pnpm validate:manifests`, `pnpm validate:docs`,
   `pnpm validate:artifacts`, `pnpm validate:compat`, and `pnpm validate:install`.

Copy an existing skill (e.g. `dw-handoff`) as a starting point.

## When adding a plugin-level (shared) script

1. Put the real file once under `scripts/runtime/<script>.sh` (`chmod +x`).
2. For each plugin that ships it:
   `ln -s ../../../../scripts/runtime/<script>.sh plugins/<plugin>/scripts/runtime/<script>.sh` AND
   `git add` the symlink (must be mode 120000, like the skill symlinks).
3. Invoke it by resolving the absolute `<this-skill-dir>/../../scripts/runtime/<script>.sh` path.
4. Add the basename to the `RUNTIME_SCRIPTS` list in `scripts/validate-manifests.sh`, and — where
   it has testable logic — a `scripts/tests/<script>.test.sh` (anchored to the repo root via
   `git rev-parse --show-toplevel`, like `validate-ai-artifacts.test.sh`).

A script used by only **one** skill stays bundled in that skill's `scripts/` dir instead (invoked
via `<this-skill-dir>/…`), e.g. `dw-doctor` — no canon/symlink needed.

## CI

Runs on every PR + push to `main`:

Workflow and job display names use verb-first sentence case and match each other, for example
`Validate docs` or `Scan secrets`. Matrix jobs append their OS and tool version. Every step has a
short verb-first name, action references are pinned to a commit SHA, and workflow filenames use
kebab-case `.yaml`.

- `pnpm lint` — `agnix` validates `CLAUDE.md`/`SKILL.md`/manifests.
- `pnpm format` — `prettier --check` (`proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version sync.
- `pnpm validate:artifacts` — `.ai/` artifact schema + runtime-script self-tests under `scripts/tests/`.
- `pnpm validate:docs` — public docs ↔ skills sync (dead links, undocumented skills, explicit-invoke
  `⭑` consistency).
- `pnpm validate:compat` — cross-host metadata, description budget, explicit-only parity, paths,
  and unified version.
- `pnpm validate:install` — isolated Codex and Claude marketplace/cache smoke.
- `trufflehog` secrets scan.
