---
branch: codex/codex-support
base: main
input: branch
created: 2026-07-13
sources: fix.md (blockers pass) — re-review after bc4ea71 · 775e91a · 9fea55d
---

# Review — Codex support: cross-host hooks, plugin restructure, install/compat validators

Multi-axis re-review after the `dw-fix blockers` pass. Every finding points at a real `file:line`;
a clean axis is "— none —", not an omission. Findings marked **(reproduced)** were confirmed by
executing the code; **(plausible)** means the mechanism is real but the trigger depends on
unverified host behavior. Hook findings apply to both the live `.claude/hooks/` copy and its
byte-identical template twin under `skills/dw-bootstrap/references/templates/hooks/`.

## Verdict

**approve-with-comments** — all three high findings from the previous review are fixed and pinned
by extended self-tests; the open worklist is medium/low only.

## Resolved since the previous review

- high · `block-env-access.sh:56` — apply_patch body false-block → fixed `bc4ea71` (branch made
  terminal; 5 new test cases, 36/36 green; twins verified identical).
- medium · `block-env-access.sh:54` — missing `Move to:` arm, quoted-target bypass → fixed
  `bc4ea71` (same change, as the review prescribed).
- high · `hook-common.sh:67` — backtick-extraction regression → fixed `775e91a` (first backticked
  span extracted; regression test, 13/13 green).
- high · `skills/dw-bootstrap/SKILL.md:96` — no Codex prune step → fixed `9fea55d` (step 5 +
  Templates list now instruct pruning `.codex/hooks.json`).
- low · `block-env-access.sh` token-scan cost on patch bodies — fell out of `bc4ea71`.

## Findings

Grouped by axis, worst severity first. Open items only — resolution history lives in `fix.md`.

### Correctness

| Severity | Location                                                                 | Finding                                                                                                                                                                                                                                      | Suggested fix                                                                                                                         |
| -------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| medium   | `skills/dw-doctor/scripts/doctor.sh:24`                                  | `--platform` as the last argument: `shift 2` with one remaining arg fails without shifting, so the `while` loop spins forever at 100% CPU **(reproduced hang)**                                                                              | Require a value before shifting (check `$#` is at least 2, else print usage and exit 2)                                               |
| medium   | `scripts/validate-install.sh:35`                                         | `find ... -exec test -x {} \;` (also line 67) never propagates the test's failure — the executable-bit assertions are no-ops and can never fail **(reproduced)**                                                                             | Use doctor.sh's own idiom: `find ... ! -perm -u+x` piped to a fail-if-nonempty check                                                  |
| medium   | `skills/dw-doctor/scripts/doctor.sh:370`                                 | Codex branch validates `.codex/hooks.json` with `jq empty` only — a hooks.json referencing a missing script reports OK **(reproduced)** — while `skills/dw-doctor/SKILL.md:38` claims each referenced `*.sh` is checked on both platforms    | Port the Claude per-script loop (doctor.sh:340–356) to the Codex branch                                                               |
| medium   | `skills/dw-bootstrap/references/templates/hooks/lint-on-edit.sh:12`      | All five hooks source `hook-common.sh` with no existence check; a missing lib is swallowed by the or-exit-0 fallback and the guardrail silently no-ops **(reproduced)** — doctor.sh cannot detect it because the lib is sourced, never wired | Fail closed when the lib is missing (message to stderr, exit 2), and teach doctor.sh to check for `hook-common.sh`                    |
| medium   | `skills/dw-bootstrap/SKILL.md:112`                                       | Step 5 still instructs building `{{HOOKS_INSTALLED}}`, but no template carries that placeholder — the only occurrence in the repo is the instruction itself (the old CLAUDE.local.md template section was deleted)                           | Re-add the placeholder to whichever template now owns the hooks inventory, or drop the instruction                                    |
| medium   | `skills/dw-review/SKILL.md:35`                                           | Seven skills (dw-conform:36, dw-explain:33, dw-fix:44, dw-prune:36, dw-review:35, dw-risk:36, dw-verify:34) invoke `<runtime-dir>` without defining it, unlike dw-build/dw-resume/dw-spec/dw-sync which resolve it explicitly                | Add the one-line "Resolve `<runtime-dir>` to the absolute `<this-skill-dir>/../../scripts/runtime` path" sentence to the seven skills |
| medium   | `scripts/validate-install.sh:56`                                         | Payload census (17/5/5; per-plugin 5/0 · 5/5 · 7/1) hardcoded in four files (also doctor.sh:130+170, doctor.test.sh:39–41+90–92, validate-compat.mjs:124); doctor.test.sh fixtures are synthetic, so census-vs-repo drift is invisible to CI | Derive counts from the repo where available; have validate-compat assert doctor.sh's census constants match the repo                  |
| low      | `scripts/tests/doctor.test.sh:100`                                       | `contains "claude-complete-misc"` matches the label on both the ok and fail paths — the dw-misc and dw-planning census assertions can never fail                                                                                             | Assert the full `complete: ...` message, as line 101 does for dw-quality                                                              |
| low      | `scripts/validate-install.sh:51`                                         | Error message renders a double-@ identifier (`dw-misc@dw-skills@0.4.0`) because `$id` already contains `@dw-skills`                                                                                                                          | Print plugin id and expected version separately                                                                                       |
| low      | `scripts/validate-install.sh:27`                                         | When the cache parent dir is missing, `find` under set-e/pipefail kills the script before the `::error::Codex cache missing` diagnostic prints **(reproduced — the version pin itself is NOT bypassed)**                                     | Guard the fallback with a directory check, or fail immediately on the pinned path                                                     |
| low      | `scripts/validate-compat.mjs:91`                                         | Folded-scalar regex stops at the first blank line inside a `>-` block, under-counting the description budget **(plausible — no current SKILL.md is affected)**                                                                               | Allow blank lines in the capture, or parse frontmatter YAML-aware                                                                     |
| low      | `skills/dw-bootstrap/references/templates/hooks/typecheck-on-stop.sh:13` | The Stop hook was fully rewritten onto the new machinery, but hook-runtime.test.sh covers only the two lint hooks — zero coverage for the bug classes reproduced (and now fixed) in its siblings                                             | Add Stop-hook cases (label match, skip-var, argv-reject path)                                                                         |

### Readability

| Severity | Location                           | Finding                                                                                                                                             | Suggested fix                                                |
| -------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| low      | `scripts/validate-install.sh:32`   | Lines 32–35 are bare `[ ... ]` assertions relying on set-e with no message, unlike every neighbouring check's explicit `::error::` branch           | Give these checks the same self-describing failure branch    |
| low      | `scripts/tests/doctor.test.sh:104` | `CLAUDE_FIXTURE` is assigned twice on the same line; the dead outer assignment leaks into later cases, which pass only because each re-overrides it | Use the sibling form (single assignment inside the subshell) |

### Architecture

| Severity | Location                                                    | Finding                                                                                                                                                                                                                    | Suggested fix                                                                                                               |
| -------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| medium   | `.claude/hooks/hook-common.sh:1`                            | The five live hooks are hand-maintained copies of the bootstrap templates — kept identical through the blockers pass by manual `cmp`, but nothing enforces it, and hook-runtime.test.sh exercises only the template copies | Add a `cmp` loop to validate-artifacts.sh (or symlink the live hooks to the templates, as `plugins/*/scripts/runtime` does) |
| low      | `scripts/validate-compat.mjs:18`                            | Canonical-version invariant enforced twice (also `scripts/validate-manifests.sh:23–31`), in two languages, both CI gates                                                                                                   | Keep one owner — compat's map is a strict superset                                                                          |
| low      | `scripts/validate-compat.mjs:102`                           | "Explicit-only" derived by two different parsers (`validate-docs.sh:32` whole-file grep vs frontmatter-scoped regex here) that can disagree                                                                                | Single owner for the derivation                                                                                             |
| low      | `scripts/validate-compat.mjs:8`                             | `minimumCodexVersion` cross-checked in 4 spots; README:46+212, AGENTS.md:40, CONTRIBUTING.md:28, docs/WORKFLOWS.md:57, docs/DESIGN.md:139, validate-install.sh:17 and dw-doctor SKILL.md:42 carry unchecked literals       | Sweep docs for Codex-version literals that differ from the constant                                                         |
| low      | `.github/workflows/validate-codex-compatibility.yaml:41`    | Claude CLI pin `2.1.179` hardcoded independently here and in `validate-plugin-manifests.yaml:37`, uncrosschecked                                                                                                           | Fold the pin into validate-compat.mjs, or a shared repo variable                                                            |
| low      | `.gitignore:13`                                             | The `.agents/plugins/` re-include unignores the whole directory, so stray files there are committable **(fix verified in a synthetic repo)**                                                                               | Insert a `/.agents/plugins/*` re-ignore before the marketplace.json negation                                                |
| low      | `skills/dw-bootstrap/SKILL.md:34`                           | The branch documents `.codex/` as tracked (gitignore-block.txt agrees), yet the repo's own `.codex/` is untracked and unignored, with stale machine-absolute paths and Claude-style matchers                               | Regenerate `.codex/` from the new template and commit it                                                                    |
| low      | `skills/dw-doctor/scripts/doctor.sh:55`                     | `version_at_least()` duplicates the pre-existing `ver_ge()` (line 190) with swapped argument order — consolidation verified behavior-identical on 8 pairs                                                                  | Delete one comparator                                                                                                       |
| low      | `skills/dw-bootstrap/references/templates/settings.json:38` | Hook headers document wiring incl. `apply_patch` matchers, but the settings.json template (and the repo's own settings) still wire the old matcher sets — contradictory guidance, harmless on Claude today                 | Align the header comment's wiring instruction with what the templates wire                                                  |

### Security

| Severity | Location                                                       | Finding                                                                                                                                                                                                                                           | Suggested fix                                                                                                                |
| -------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| medium   | `skills/dw-bootstrap/references/templates/codex-hooks.json:5`  | **(plausible)** Shell guards dispatch on matcher `"Bash"` and assume a string command; an argv-array payload was reproduced to defeat both tokenizers (force-push not blocked), and nothing in the repo pins Codex's actual event shape           | Capture a real Codex PreToolUse event as a fixture and assert the contract in CI; handle array commands via a jq type branch |
| medium   | `.claude/hooks/block-dangerous-commands.sh:13`                 | Both block-\* hooks fail open without jq, and their headers claim a `permissions.deny` backstop that exists only on the Claude side — a jq-less Codex host runs unguarded while the shipped comment claims otherwise                              | Scope the comment per host; consider failing closed on Codex or documenting the degradation in codex-hooks.json              |
| low      | `skills/dw-bootstrap/references/templates/codex-hooks.json:10` | **(plausible)** Hook commands resolve scripts via `$(git rev-parse --show-toplevel)` at run time; outside a worktree it expands empty and the guard dies with exit 127 — no cwd guarantee documented                                              | Guard the empty expansion, or document the cwd requirement                                                                   |
| low      | `.claude/hooks/block-env-access.sh:56`                         | **(new, plausible)** Extracted header paths are quote-stripped but not whitespace-trimmed; if the host trims path whitespace when applying a patch, a padded `.env ` header slips the now-terminal scan (the old body-scan caught it by accident) | Trim surrounding whitespace alongside the quote strip                                                                        |

### Performance

| Severity | Location                                                | Finding                                                                                                                                                                                            | Suggested fix                                                                                 |
| -------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| medium   | `.github/workflows/validate-codex-compatibility.yaml:3` | No `paths:` filter (siblings have one), the static `pnpm validate:compat` runs identically in all 4 matrix cells, and the pinned CLIs are npm-installed per cell with no cache — 2 cells are macOS | Add a `paths:` filter; hoist validate:compat to one ubuntu job; cache the npm-global installs |
| low      | `.claude/hooks/hook-common.sh:40`                       | 3 jq spawns per Edit/Write on the hottest hook path, plus per-candidate repo-root re-canonicalization (~15–40 ms avoidable per edit)                                                               | One jq call emitting tool_name + path; canonicalize the root once per invocation              |

## Summary

**approve-with-comments** — the three blockers are fixed, each pinned by a new self-test case and
applied identically to both hook copies; no critical or high finding remains. The re-review of the
fix hunks surfaced one new low (untrimmed whitespace in extracted patch-header paths, contingent on
host trim behavior). Of the open mediums, the two worth doing before merge are the doctor.sh
infinite loop (`doctor.sh:24` — a one-line guard) and the dead executable-bit assertions
(`validate-install.sh:35` — the check CI currently pretends to run); the most consequential open
question remains the unpinned Codex hook event shape (`codex-hooks.json:5`), best settled with one
captured real event. Previously noted out-of-scope items stand: the lint-on-edit outside-repo drop
is intentional and security-positive, the double agnix scan is forced by agnix's CLI, and the Codex
marketplace's missing version field is a CLAUDE.md wording nit.
