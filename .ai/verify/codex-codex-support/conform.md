---
branch: codex/codex-support
base: main
input: branch
created: 2026-07-13
sources: review.md (approve-with-comments) · fix.md (blockers + pass 2)
---

# Conform — Codex support: cross-host hooks, plugin restructure, install/compat validators

Conformance check: does this branch match the repo's existing, pre-committed patterns? Every drift
cites both the changed line and the pre-existing referent it diverges from (confirmed via `git log` /
`git show main:` to pre-date the branch). First-of-their-kind Codex surfaces with no sibling to
compare against go under No-precedent notes, not drift.

## Verdict

**minor-drift** — the branch fits the repo well; five contained medium/low divergences, none
blocking. The one worth aligning first is the second version comparator in `doctor.sh` that bypasses
the one already there.

## Drift findings

Location is `path:line` in the change; Pattern referent is a pre-existing `path:line` the change
should have followed.

| Severity | Location                                                | Drift                                                                                                                                                                | Pattern referent (pre-existing)                                                                                        | Suggested alignment                                                                           |
| -------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| medium   | `skills/dw-doctor/scripts/doctor.sh:57`                 | adds `version_at_least()`, a second SemVer comparator (args swapped), instead of reusing the one already in the same file                                            | `skills/dw-doctor/scripts/doctor.sh:192` — `ver_ge()`, present on `main`                                               | delete one comparator; call the pre-existing `ver_ge` (behaviour verified identical)          |
| medium   | `scripts/validate-install.sh:3`                         | `set -euo pipefail` — adds `-e`, unlike its sibling CI validators, which all run `set -uo pipefail`                                                                  | `scripts/validate-manifests.sh:3` (also `validate-docs.sh:11`, `validate-artifacts.sh:6`)                              | drop `-e` to match the validator class and give each check its own exit branch (row below)    |
| medium   | `.github/workflows/validate-codex-compatibility.yaml:3` | `on:` has no `paths:` filter, so a heavy 4-cell (2× macOS) matrix runs on every push; the other targeted-validator workflows all scope themselves                    | `.github/workflows/validate-plugin-manifests.yaml:3` (also `validate-docs.yaml`, `validate-ai-artifacts.yaml`)         | add a `paths:` filter covering the Codex/compat surface, mirroring the sibling validators     |
| medium   | repo `.codex/` (untracked — `git status: ?? .codex/`)   | the repo commits its agent infra, and this branch's own gitignore-block documents `.codex/` as tracked, yet the repo's `.codex/` is neither tracked nor ignored      | `.claude/hooks/*` + `.claude/settings.json` tracked; `skills/dw-bootstrap/references/templates/gitignore-block.txt:15` | regenerate `.codex/` from the current template and commit it, as `.claude/` is committed      |
| low      | `scripts/validate-install.sh:32`                        | three bare `[ ... ]` count assertions with no message, working only because of the drifted `-e`, while 14 checks in the same file use an explicit `::error::` branch | `scripts/validate-install.sh:28` — the `Codex cache missing` branch; `scripts/validate-manifests.sh`                   | wrap each in `... \|\| { echo "::error::..."; exit 1; }`, self-describing like its neighbours |

## No-precedent notes

First-of-their-kind Codex surfaces with no existing sibling to conform to — recorded for honesty, not
as drift:

- **Cross-host hook adapter** (`.claude/hooks/hook-common.sh`, `skills/dw-bootstrap/references/templates/codex-hooks.json`)
  — the repo's first Codex hook layer; no prior Codex-hook shape to match.
- **Codex agent policy** (`skills/{dw-bootstrap,dw-handoff,dw-prune,dw-setup-precommit,dw-sync}/agents/openai.yaml`)
  — first explicit-invoke policy files for Codex; the Claude side has no direct analogue.
- **Codex aggregate plugin + marketplace** (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`)
  — intentionally aggregate (one entry over the real `skills/`), by design different from the
  per-plugin Claude marketplace per `CLAUDE.md`; conforms-by-design, no matching precedent.
- The moved runtime scripts (`scripts/runtime/*`, `plugins/*/scripts/runtime/*`) **establish** the new
  script-organization convention `CLAUDE.md` documents — the restructure is the pattern, not a drift.

## Summary

**minor-drift** — this is a large, careful branch that mostly extends the repo in its own idiom: the
new self-tests (`doctor.test.sh`, `hook-runtime.test.sh`) match the sibling test harness
(`note_pass`/`note_fail`, jq-skip guard, `git rev-parse --show-toplevel` anchoring), and the new
workflow matches the CI conventions (verb-first sentence-case names, pinned action SHAs, a
`concurrency:` block) — its only divergences are the missing `paths:` filter and, consistently with
its sibling, the hardcoded Claude CLI pin (a single-sourcing concern that belongs in `review.md`, not
here, since the new workflow _matches_ precedent). Align first the duplicate `version_at_least`
comparator in `doctor.sh` (bypasses the pre-existing `ver_ge`), then the `validate-install.sh`
error-handling divergence (`-e` + bare asserts vs the sibling validators' `set -uo` + `::error::`
idiom — these two are coupled), the workflow `paths:` filter, and committing the repo's own `.codex/`
so it dogfoods the tracked-agent-infra pattern it documents. Everything else is first-of-their-kind
Codex scaffolding with no precedent to drift from. Internal bugs and quality (the reproduced
`doctor.sh` / `validate-install.sh` issues, already fixed) live in `review.md`, not here.
