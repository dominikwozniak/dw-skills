# dominikwozniak-skills — agent instructions

A personal bucket of Claude Code skills, distributed as an installable plugin marketplace — not a
code project.

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` is a **git-tracked symlink** (mode 120000) → `../../../skills/<name>`, plus
  `plugins/<name>/.claude-plugin/plugin.json`.
- **`scripts/`** — `validate-manifests.sh` (backs `pnpm validate:manifests`).
- **`.claude-plugin/marketplace.json`** — makes this repo installable as a Claude Code plugin
  source.

## Conventions

- Skills use YAML frontmatter; `disable-model-invocation: true` for explicit-invoke-only skills.
- Skill name: kebab-case, matches the directory name.
- Canonical file is `skills/<name>/SKILL.md` — edit there, never via the plugin symlink.
- `marketplace.json` version must match the plugin's `plugin.json` version (checked by
  `pnpm validate:manifests`).

## When adding a new skill

1. Create `skills/<name>/SKILL.md` (kebab-case `name`, `description` with trigger phrases).
2. Create `plugins/<name>/.claude-plugin/plugin.json` AND
   `ln -s ../../../skills/<name> plugins/<name>/skills/<name>` AND `git add` the symlink.
3. Add a row to `.claude-plugin/marketplace.json` (version in sync with `plugin.json`).
4. Bump the plugin's patch version in **both** `plugins/<name>/.claude-plugin/plugin.json` and the
   matching `.claude-plugin/marketplace.json` entry — they must stay in sync (CI enforces it via
   `validate-manifests.sh`).
5. Update the README skill list.
6. `pnpm lint && pnpm format && pnpm validate:manifests`.

Copy an existing skill (e.g. `dw-handoff`) as a starting point.

## CI

Runs on every PR + push to `main`:

- `pnpm lint` — `agnix` validates `CLAUDE.md`/`SKILL.md`/manifests.
- `pnpm format` — `prettier --check` (`proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version sync.
- `trufflehog` secrets scan.
