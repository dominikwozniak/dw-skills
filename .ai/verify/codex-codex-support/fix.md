---
branch: codex/codex-support
base: main
created: 2026-07-13
sources: review.md
---

# Fix — blockers pass (dw-fix blockers)

## Summary

All 3 high findings from `review.md` (verdict: request-changes) fixed, one commit each; the coupled
medium `Move to:` security finding was fixed in the same commit as the env-guard blocker, as the
review itself prescribed. Self-tests extended to pin each fix (env guard 36/36, hook runtime 13/13,
`pnpm validate:artifacts` / `validate:docs` / `validate:compat` all green).

## Applied

| Severity | Location                               | Finding                                                                                          | Fix commit                                                                                                                                 |
| -------- | -------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| high     | `.claude/hooks/block-env-access.sh:56` | apply_patch fell through the header scan into the whole-body token scan (false-blocks)           | `bc4ea71` — apply_patch branch made terminal; both copies + 5 new test cases                                                               |
| medium   | `.claude/hooks/block-env-access.sh:54` | header scan missed `Move to:` rename targets; quoted target bypassed the guard                   | `bc4ea71` — `Move to:` arm added, surrounding quotes stripped (fixed with the blocker above, as one change per the review's suggested fix) |
| high     | `.claude/hooks/hook-common.sh:67`      | `dw_hook_local_command` no longer extracted the backticked command; annotations broke every edit | `775e91a` — first backtick-delimited span extracted when present; both copies + regression test                                            |
| high     | `skills/dw-bootstrap/SKILL.md:96`      | Codex bootstrap installed `codex-hooks.json` verbatim with no prune step                         | `9fea55d` — prune instruction added to step 5 and the Templates list, mirroring the settings.json wording                                  |

# Fix — pass 2 (targeted medium/low)

## Summary

After the re-review confirmed the blockers clean, this pass cleared the six highest-value medium/low
findings — two reproduced bugs and four hardening/scaffold fixes — one logical commit each, verified
against the repo's own self-tests. Hook fixes mirrored into both copies (`cmp`-identical). Full
suite green: `validate:artifacts` / `docs` / `compat` / `manifests` / `format`.

## Applied

| Severity   | Location                                  | Finding                                                        | Fix commit                                                                 |
| ---------- | ----------------------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------- |
| medium     | `skills/dw-doctor/scripts/doctor.sh:24`   | `--platform` last-arg → `shift 2` fails → 100% CPU loop        | `9b230f9` — value-guard before shift; portable no-hang test                |
| medium     | `scripts/validate-install.sh:35` / `:67`  | `find -exec test -x` always exits 0 → check can't fail         | `488bd9a` — capture `! -perm -u+x` and fail on non-empty; scratch-verified |
| medium     | `lint-on-edit.sh:12` (+ 3 template hooks) | missing `hook-common.sh` swallowed → guardrail silently no-ops | `de448fb` — fail-closed guard before `source`; missing-lib test            |
| medium     | `skills/dw-bootstrap/SKILL.md`            | dangling `{{HOOKS_INSTALLED}}` — no template carried it        | `aa02368` — `## Hooks installed` section added to the AGENTS.md template   |
| medium     | seven dw-quality skills                   | `<runtime-dir>` used but never resolved                        | `9dc53dd` — resolution sentence added to each canonical SKILL.md           |
| low (sec)  | `.claude/hooks/block-env-access.sh:56`    | patch-header paths not whitespace/CRLF trimmed                 | `5a433e3` — bash-3.2 trim around the quote strip; padded + CRLF tests      |
| low (arch) | `.gitignore`                              | `!/.agents/plugins/` re-includes the whole dir                 | `5a433e3` — `/.agents/plugins/*` re-ignore; `git check-ignore` verified    |

## Deferred (separate PRs)

Left open by design — lower value or needing out-of-repo input, all recorded in `review.md`:

- **Codex hook event-shape contract** (`codex-hooks.json:5`, plausible security) — needs a captured
  real Codex PreToolUse event to confirm matcher/argv handling; can't be settled from the repo.
- **Payload-census single-sourcing** (17/5/5 across four files) and the **doctor.sh Codex-branch
  per-script check** (`doctor.sh:370`) — structural, medium.
- **Validator dedup** (version-sync + explicit-set enforced twice), **doc version-literal sweep**,
  **Claude CLI pin cross-check**, **CI matrix `paths:` filter + validate:compat hoist**, **jq
  hot-path**, **duplicate `ver_ge`/`version_at_least`**, **hook live-vs-template `cmp` gate**,
  **doctor.test.sh tautological assertion**, **settings.json matcher wording** — low, tidy-ups.

# Fix — pass 3 (codex:review findings)

## Summary

An independent `codex:review` branch pass surfaced seven `[P2]` Codex-path findings. The load-bearing
claims were verified against the code first (Codex did not hallucinate on the checked ones; #6 matches
the earlier `doctor.sh:370` finding). This pass fixed the three "tool lies about health / guardrail
silently off" items — all in `doctor.sh` — one commit each, each pinned by new self-tests
(`doctor.test.sh` 15 → 22). Full suite green: `validate:artifacts` / `docs` / `compat` / `manifests`
/ `format`.

## Applied

| Severity | Location        | Finding                                                        | Fix commit                                                          |
| -------- | --------------- | -------------------------------------------------------------- | ------------------------------------------------------------------- |
| medium   | `doctor.sh:373` | Codex hooks validated with `jq empty` only — broken wiring OK  | `0b8171f` — per-script existence + exec-bit check; 4 new tests      |
| medium   | `doctor.sh:380` | declined/untrusted Codex hooks still reported healthy          | `d5b97dc` — explicit note that trust is Codex-managed, unverifiable |
| medium   | `doctor.sh:202` | `auto` with no adapter dir picks claude, hides every Codex gap | `71bec54` — check both + warn; SKILL.md passes explicit host        |

## Deferred (separate PRs)

Held back deliberately — either out-of-repo input needed or lower-value bootstrap polish:

- **#3 patch-path `cwd`** (`hook-common.sh:16`, med) — hooks resolve relative ApplyPatch paths from the
  repo root, not the event `cwd`; from a subdir under Codex the lint hook silently skips the edit. A
  correct fix needs a **captured real Codex hook event** (payload `cwd` + relative-path base); fixing
  blind risks resolving to the wrong file. Same dependency as the `codex-hooks.json:5` event-shape item.
- **#1 codex-only settings copy** (`dw-bootstrap/SKILL.md:95`, med) and **#2 unignore generated tracked
  adapters** (`dw-bootstrap/SKILL.md:123`, med) — bootstrap-flow correctness; batch into a bootstrap PR.
- **#4 tracked `DW.local.md` trust** (`hook-common.sh:66`, low) — require the source be ignored **and**
  untracked before trusting its command; defense-in-depth hardening.

## Next

The `doctor.sh` health-accuracy cluster is closed. Remaining work is the deferred bootstrap/hook
items above (own PRs) — #3/#4 best tackled after capturing a real Codex hook event. Re-run
`dw-review` for a fresh verdict if desired (optional — still no blocker), then `dw-verify` to prove
the change still runs before the PR.
