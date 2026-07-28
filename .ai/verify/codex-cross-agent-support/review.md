---
branch: codex-cross-agent-support
base: main
input: working-diff
created: 2026-06-23
sources: none — reviewed from the diff (no sibling artifacts in .ai/verify/)
---

# Review — Codex cross-agent support + skill-relative script layout

Multi-axis review — correctness, readability, architecture, security, performance. Every finding
points at a real `file:line`; clean axes are "— none —".

## Verdict

**approve-with-comments** — migration is mechanically correct and verified; no blockers. One thing
worth fixing before it bites: the new `.codex/skills/<name>` convention isn't wired into the
add-a-skill checklist or CI, so new skills will silently miss Codex-in-repo.

## Findings

### Correctness

| Severity | Location                      | Finding                                                                                                                                                                                                               | Suggested fix                                                                                                            |
| -------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| low      | `scripts/install-codex.sh:38` | `installed=$((installed + 1))` runs unconditionally after `ln -sfn`. Script is `set -uo pipefail` (no `-e`), so a failed `ln` (e.g. permission) is counted as linked — final "Done: N linked" can overcount silently. | Gate the increment on `ln` success: `if ln -sfn … "$link"; then …; installed=…; else echo FAIL; fi`. **✔ fixed 6f59fc8** |

### Readability

| Severity | Location                          | Finding                                                                                                                                                                                                                    | Suggested fix                                                                              |
| -------- | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| low      | `scripts/validate-manifests.sh:4` | File-header comment still says scripts are "symlinked into each **plugin's** scripts/ dir" — stale after this change. The echo + body now correctly say "each consuming **skill**" (line 36); the header contradicts them. | Update line 4 to "symlinked into each consuming skill's scripts/ dir". **✔ fixed 193ed86** |

### Architecture

| Severity | Location                           | Finding                                                                                                                                                                                                                                                                                                                                                                                                                    | Suggested fix                                                                                                                                            |
| -------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| medium   | `AGENTS.md:43` (step 2)            | This change introduces the in-repo `.codex/skills/<name>` convention but the "When adding a new skill" checklist never tells the contributor to create the `.codex/skills/<name>` symlink. A new skill gets its `plugins/` symlink but no `.codex/` one → invisible to Codex working in-repo (machine-wide `install-codex.sh` targets `~/.codex`, a different path). The repo's most common operation silently half-works. | Add a checklist sub-step: `ln -s ../../skills/<name> .codex/skills/<name>` + `git add` it, beside step 2's plugin symlink. **✔ fixed 6510d13**           |
| medium   | `scripts/validate-manifests.sh:63` | Nothing asserts `.codex/skills/` stays in sync with `skills/`. The new CI checks cover skill-script symlinks, `CLAUDE_PLUGIN_ROOT`, and doubled placeholders — but a `skills/<name>` with no `.codex/skills/<name>` (or a dangling `.codex` link) passes CI green. This is the enforcement half of the gap above; together they let the new convention rot unnoticed.                                                      | Add a loop asserting every `skills/*/` has a resolving `.codex/skills/<name>` → `../../skills/<name>`, and no `.codex` link dangles. **✔ fixed dfd10b8** |

### Security

— none —

(`install-codex.sh` only manages its own symlinks under `$DEST`, refuses to clobber real
files/dirs (`scripts/install-codex.sh:28`), uses absolute targets, takes no untrusted input, leaks
no secrets.)

### Performance

— none — (not applicable: symlinks, docs, shell tooling — no hot path.)

## Summary

**approve-with-comments.** This is a clean, well-executed refactor: the script canon moves to
`scripts/runtime/` with skill-relative invocation, `${CLAUDE_PLUGIN_ROOT}` is fully retired (verified:
zero references in `skills/`), and Codex support lands via committed `.codex/skills/` symlinks + an
idempotent `install-codex.sh`. I verified the mechanics end-to-end read-only — all 17 skills are
linked in `.codex/skills/`, every `skills/*/scripts/*.sh` symlink resolves into the canon, the canon
is executable, new links are mode `120000`, and `CLAUDE.md`→`AGENTS.md` is accurate. Docs and CI
checks (the `CLAUDE_PLUGIN_ROOT` + doubled-placeholder guards) are genuinely good additions.

The one thing to address first: the new `.codex/skills/<name>` convention has no home in the
contribution process — neither the add-a-skill checklist (`AGENTS.md:43`) nor CI
(`validate-manifests.sh`) accounts for it. Today all 17 skills are linked correctly, so nothing is
broken; but the next skill added will silently miss Codex-in-repo, and CI won't catch it. Closing both
halves — one checklist line + one CI loop — makes the new layout self-maintaining like the rest of the
repo. The two `low`s (a miscount on `ln` failure, a stale header comment) are nits.

Reviewed but out of scope: the broader `plugins/` ↔ `skills/` symlink topology and existing CI checks
predate this branch and are unchanged in substance.
