# dw-bootstrap — procedure detail

Read this before running **tuned** mode or any migration. The SKILL body is the
spine; this fills in the parts that don't belong in the discovery surface.

## Why tracked, not throwaway

claude-kit (and the addy-osmani convention it wires) gitignores everything the
agent produces: `.agent/`, `settings.local.json`, `.claude/hooks/`. dw-\* inverts
that. Specs, plans, handoffs, and the guardrail hooks are **shared work** — a
teammate or a fresh session should get the same loop and the same guardrails
without re-bootstrapping. So:

- `.ai/` is **tracked** — `dw-spec` writes `.ai/runs/<id>/SPEC.md`, `dw-build`
  appends `NOTES.md`, `dw-handoff` writes `.ai/handoffs/<ts>.md`. All committed.
- `.claude/settings.json` + `.claude/hooks/` are **tracked** — a committed
  `settings.json` that references hook scripts only works if the scripts are in
  the repo too.
- `CLAUDE.local.md` and `.claude/settings.local.json` stay **personal/ignored** —
  the About-me, language preferences, and any local-only overrides are yours, not
  the team's.

The single ambiguous case is `CLAUDE.md`: if the repo wants _shared_ project
memory, that's a tracked `CLAUDE.md` distinct from your personal
`CLAUDE.local.md`. dw-bootstrap writes only `CLAUDE.local.md`; leave any existing
`CLAUDE.md` alone unless asked.

## Stack → hooks

| Hook                  | When to offer                   | Notes                                                                                                       |
| --------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `block-dangerous-git` | always                          | stack-agnostic; blocks force-push, hard-reset, `clean -f`, `branch -D`, `checkout .`, `restore .`           |
| `block-non-pnpm`      | JS/TS (a `package.json` exists) | blocks `npm`/`yarn`/`bun`; allows `pnpm`, `pnpm dlx`, `npx`                                                 |
| `lint-on-edit`        | JS/TS                           | reads the **Lint command** from `CLAUDE.local.md`; falls back to eslint; skips silently if neither resolves |

For Ruby / Rust / Python / Go: wire `block-dangerous-git` and tell the user the
lint/typecheck hooks are JS/TS-specific. If they want a stack-equivalent lint hook
(e.g. `bundle exec standardrb` on save), write a sibling script by the same
shape — read stdin JSON, gate on the file extension, `exit 2` on failure — but
don't ship one speculatively.

All hooks no-op without `jq` (`command -v jq || exit 0`). Mention `brew install jq`
in the report if it's missing.

## Interview (tuned mode)

Ask only what you can't detect. Keep each answer to a line or two; skip whatever
the user waves off. Map answers into the matching `CLAUDE.local.md` sections.

**About me / preferences**

1. Primary stack, and what you're newer at on _this_ project.
2. Communication language (e.g. English; or "Polish + English, technical terms in
   EN"). Confirm code/identifiers/commits/PRs stay EN regardless.
3. Learning mode — minimal vs verbose; when to add analogies from a stack you know
   (a cheat-sheet table like Ruby↔TypeScript belongs here if useful).

**Project specifics** (seed from detection, confirm with the user)

4. Domain — one-line gist or a pointer to `CLAUDE.md` / docs.
5. Key directories — where business logic lives.
6. Deployment target — how/where it ships.
7. Gotchas — local-only traps worth recording now.

**Git conventions**

8. Commit format — ticket-prefixed (`[ABC-123] type: desc`) or plain
   Conventional Commits; how the branch encodes a ticket, if at all.
9. Trailer policy — e.g. NO `Co-Authored-By`, NO "Generated with Claude Code".
10. Rebase vs merge; signing (note if SSH signing is already configured globally —
    don't re-configure it, just record that plain `git commit` signs).

## Idempotent re-runs

dw-bootstrap is safe to run again on an already-bootstrapped repo:

- **`.gitignore`** — the managed block is fenced by
  `>>> dw-bootstrap managed block >>>` / `<<< dw-bootstrap managed block <<<`.
  Replace the block in place; never append a second copy.
- **`.ai/` dirs** — `mkdir -p`; never delete or overwrite existing run folders.
- **`settings.json` / hooks** — these are tracked; show a diff and confirm before
  overwriting a customized file. Prefer merging the user's edits over clobbering.
- **`CLAUDE.local.md`** — if it already has real content, do **not** overwrite.
  Offer to merge missing sections (e.g. add a `## Hooks installed` block) instead.

## Migrating off claude-kit

Signals: a `.agent/` directory, a `settings.local.json` carrying the hooks, or
`/spec → /plan → /build` references in `CLAUDE.md` / `CLAUDE.local.md`.

Consent-gated steps — present the plan, write nothing without a yes:

1. **Memory dir** — `git mv .agent/<...> .ai/<...>` (or move + re-add). Map
   `.agent/handoffs/` → `.ai/handoffs/`. Preserve content.
2. **Settings** — move `settings.local.json` → `settings.json` (tracked); keep a
   `settings.local.json` only for genuinely personal overrides.
3. **Hooks** — move `.claude/hooks/` out of the ignore list so the tracked
   settings resolve for everyone.
4. **`.gitignore`** — drop the rules that ignored `/.agent/`, `settings.local.json`
   (for the shared parts), and `/.claude/hooks/`; install the managed block.
5. **Loop references** — rewrite `/spec /plan /build` → `dw-spec / dw-plan /
dw-build`, `.agent/` → `.ai/`, and the addyosmani/agent-skills link → the
   dw-\* skills, across `CLAUDE.md` and `CLAUDE.local.md`.
6. **Cross-check** — update any `## Hooks installed` / workflow lines so the file
   still matches reality (stale lines silently break the lint/typecheck flow).
