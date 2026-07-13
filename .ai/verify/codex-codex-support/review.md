---
branch: codex/codex-support
base: main
input: branch
created: 2026-07-13
sources: fix.md (blockers + pass 2) — re-review after bc4ea71 · 775e91a · 9fea55d; pass-2 fixes 9b230f9 · 488bd9a · de448fb · aa02368 · 9dc53dd · 5a433e3
---

# Review — Codex support: cross-host hooks, plugin restructure, install/compat validators

Multi-axis review of `codex/codex-support`, after two `dw-fix` passes. Every finding points at a real
`file:line`; a clean axis is "— none —". Findings marked **(reproduced)** were confirmed by executing
the code; **(plausible)** means the mechanism is real but the trigger depends on unverified host
behavior. Hook findings apply to both the live `.claude/hooks/` copy and its byte-identical template
twin under `skills/dw-bootstrap/references/templates/hooks/`.

## Verdict

**approve-with-comments** — no critical or high remains. The blockers pass cleared all three highs;
`dw-fix` pass 2 cleared the six highest-value medium/low items (incl. two reproduced bugs). The open
worklist below is lower-value medium/low, deferred to follow-up PRs.

## Resolved

### Blockers pass

- high · `block-env-access.sh:56` — apply_patch body false-block → `bc4ea71` (branch made terminal;
  5 test cases; twins identical).
- medium · `block-env-access.sh:54` — missing `Move to:` arm, quoted-target bypass → `bc4ea71`.
- high · `hook-common.sh:67` — backtick-extraction regression → `775e91a` (regression test).
- high · `skills/dw-bootstrap/SKILL.md:96` — no Codex prune step → `9fea55d`.

### dw-fix pass 2 (this iteration)

- medium · `skills/dw-doctor/scripts/doctor.sh:24` — `--platform` infinite loop → `9b230f9`
  (value-guard + portable no-hang test).
- medium · `scripts/validate-install.sh:35`/`:67` — dead `-exec test -x` checks → `488bd9a`
  (capture-and-test `! -perm -u+x`; scratch-verified).
- medium · `lint-on-edit.sh:12` (+ `lint-on-edit-rb.sh`, `typecheck-on-stop.sh`) — silent no-op when
  `hook-common.sh` is missing → `de448fb` (fail-closed guard + test; both copies).
- medium · `skills/dw-bootstrap/SKILL.md` — dangling `{{HOOKS_INSTALLED}}` → `aa02368`
  (placeholder home added to the `AGENTS.md` template).
- medium · seven dw-quality skills — undefined `<runtime-dir>` → `9dc53dd`.
- low (security) · `block-env-access.sh:56` — patch-path whitespace/CRLF trim → `5a433e3`
  (padded + CRLF test cases; both copies).
- low (architecture) · `.gitignore` — `.agents/plugins/` over-broad re-include → `5a433e3`
  (verified with `git check-ignore`).

## Findings

Open items only — resolution history is above and in `fix.md`.

### Correctness

| Severity | Location                                                                 | Finding                                                                                                                                                                                                                                   | Suggested fix                                                                                                        |
| -------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| medium   | `skills/dw-doctor/scripts/doctor.sh:370`                                 | Codex branch validates `.codex/hooks.json` with `jq empty` only — a hooks.json referencing a missing script reports OK **(reproduced)** — while `skills/dw-doctor/SKILL.md:38` claims each referenced `*.sh` is checked on both platforms | Port the Claude per-script loop (doctor.sh:340–356) to the Codex branch                                              |
| medium   | `scripts/validate-install.sh:56`                                         | Payload census (17/5/5; per-plugin 5/0 · 5/5 · 7/1) hardcoded in four files (also doctor.sh, doctor.test.sh, validate-compat.mjs); doctor.test.sh fixtures are synthetic, so census-vs-repo drift is invisible to CI                      | Derive counts from the repo where available; have validate-compat assert doctor.sh's census constants match the repo |
| low      | `scripts/tests/doctor.test.sh:100`                                       | `contains "claude-complete-misc"` matches the label on both the ok and fail paths — the dw-misc and dw-planning census assertions can never fail                                                                                          | Assert the full `complete: ...` message, as the dw-quality case does                                                 |
| low      | `scripts/validate-install.sh:51`                                         | Error message renders a double-@ identifier (`dw-misc@dw-skills@0.4.0`) because `$id` already contains `@dw-skills`                                                                                                                       | Print plugin id and expected version separately                                                                      |
| low      | `scripts/validate-install.sh:27`                                         | When the cache parent dir is missing, `find` under set-e/pipefail kills the script before the `::error::Codex cache missing` diagnostic prints **(reproduced — the version pin itself is NOT bypassed)**                                  | Guard the fallback with a directory check, or fail immediately on the pinned path                                    |
| low      | `scripts/validate-compat.mjs:91`                                         | Folded-scalar regex stops at the first blank line inside a `>-` block, under-counting the description budget **(plausible — no current SKILL.md is affected)**                                                                            | Allow blank lines in the capture, or parse frontmatter YAML-aware                                                    |
| low      | `skills/dw-bootstrap/references/templates/hooks/typecheck-on-stop.sh:13` | The Stop hook runs on the new machinery but hook-runtime.test.sh covers only the two lint hooks — no coverage for the bug classes reproduced (and now fixed) in its siblings                                                              | Add Stop-hook cases (label match, skip-var, argv-reject path)                                                        |

### Readability

| Severity | Location                           | Finding                                                                                                                                             | Suggested fix                                                |
| -------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| low      | `scripts/validate-install.sh:32`   | Lines 32–35 are bare `[ ... ]` assertions relying on set-e with no message, unlike every neighbouring check's explicit `::error::` branch           | Give these checks the same self-describing failure branch    |
| low      | `scripts/tests/doctor.test.sh:104` | `CLAUDE_FIXTURE` is assigned twice on the same line; the dead outer assignment leaks into later cases, which pass only because each re-overrides it | Use the sibling form (single assignment inside the subshell) |

### Architecture

| Severity | Location                                                    | Finding                                                                                                                                                                                                              | Suggested fix                                                              |
| -------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| low      | `scripts/validate-compat.mjs:18`                            | Canonical-version invariant enforced twice (also `scripts/validate-manifests.sh:23–31`), in two languages, both CI gates                                                                                             | Keep one owner — compat's map is a strict superset                         |
| low      | `scripts/validate-compat.mjs:102`                           | "Explicit-only" derived by two different parsers (`validate-docs.sh:32` whole-file grep vs frontmatter-scoped regex here) that can disagree                                                                          | Single owner for the derivation                                            |
| low      | `scripts/validate-compat.mjs:8`                             | `minimumCodexVersion` cross-checked in 4 spots; README:46+212, AGENTS.md:40, CONTRIBUTING.md:28, docs/WORKFLOWS.md:57, docs/DESIGN.md:139, validate-install.sh:17 and dw-doctor SKILL.md:42 carry unchecked literals | Sweep docs for Codex-version literals that differ from the constant        |
| low      | `.github/workflows/validate-codex-compatibility.yaml:41`    | Claude CLI pin `2.1.179` hardcoded independently here and in `validate-plugin-manifests.yaml:37`, uncrosschecked                                                                                                     | Fold the pin into validate-compat.mjs, or a shared repo variable           |
| low      | `skills/dw-bootstrap/SKILL.md:34`                           | The branch documents `.codex/` as tracked (gitignore-block.txt agrees), yet the repo's own `.codex/` is untracked and unignored, with stale machine-absolute paths and Claude-style matchers                         | Regenerate `.codex/` from the new template and commit it                   |
| low      | `skills/dw-doctor/scripts/doctor.sh:55`                     | `version_at_least()` duplicates the pre-existing `ver_ge()` (line 190) with swapped argument order — consolidation verified behavior-identical on 8 pairs                                                            | Delete one comparator                                                      |
| low      | `skills/dw-bootstrap/references/templates/settings.json:38` | Hook headers document wiring incl. `apply_patch` matchers, but the settings.json template (and the repo's own settings) still wire the old matcher sets — contradictory guidance, harmless on Claude today           | Align the header comment's wiring instruction with what the templates wire |

### Security

| Severity | Location                                                       | Finding                                                                                                                                                                                                                                 | Suggested fix                                                                                                                |
| -------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| medium   | `skills/dw-bootstrap/references/templates/codex-hooks.json:5`  | **(plausible)** Shell guards dispatch on matcher `"Bash"` and assume a string command; an argv-array payload was reproduced to defeat both tokenizers (force-push not blocked), and nothing in the repo pins Codex's actual event shape | Capture a real Codex PreToolUse event as a fixture and assert the contract in CI; handle array commands via a jq type branch |
| medium   | `.claude/hooks/block-dangerous-commands.sh:13`                 | Both block-\* hooks fail open without jq, and their headers claim a `permissions.deny` backstop that exists only on the Claude side — a jq-less Codex host runs unguarded while the shipped comment claims otherwise                    | Scope the comment per host; consider failing closed on Codex or documenting the degradation in codex-hooks.json              |
| low      | `skills/dw-bootstrap/references/templates/codex-hooks.json:10` | **(plausible)** Hook commands resolve scripts via `$(git rev-parse --show-toplevel)` at run time; outside a worktree it expands empty and the guard dies with exit 127 — no cwd guarantee documented                                    | Guard the empty expansion, or document the cwd requirement                                                                   |

### Performance

| Severity | Location                                                | Finding                                                                                                                                                                                            | Suggested fix                                                                                 |
| -------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| medium   | `.github/workflows/validate-codex-compatibility.yaml:3` | No `paths:` filter (siblings have one), the static `pnpm validate:compat` runs identically in all 4 matrix cells, and the pinned CLIs are npm-installed per cell with no cache — 2 cells are macOS | Add a `paths:` filter; hoist validate:compat to one ubuntu job; cache the npm-global installs |
| low      | `.claude/hooks/hook-common.sh:40`                       | 3 jq spawns per Edit/Write on the hottest hook path, plus per-candidate repo-root re-canonicalization (~15–40 ms avoidable per edit)                                                               | One jq call emitting tool_name + path; canonicalize the root once per invocation              |

## Summary

**approve-with-comments** — two `dw-fix` passes have cleared every critical/high and the six
highest-value medium/low findings, each pinned by a self-test where one applies and mirrored into
both hook copies (verified with `cmp`). Correction to an earlier claim: live-vs-template hook parity
_is_ already CI-enforced by `scripts/tests/hooks-in-sync.test.sh` (byte-identical `cmp` + executable
bit), so the "nothing enforces it" Architecture finding was withdrawn as inaccurate. The full
validate suite is green
(`validate:artifacts` / `docs` / `compat` / `manifests` / `format`). What remains is deliberately
deferred: the most consequential is the **plausible** unpinned Codex hook event shape
(`codex-hooks.json:5`) — best settled with one captured real Codex event, since nothing in the repo
proves the shell guards fire on Codex. The rest are structural single-sourcing / dedup items
(payload census, version-literal sweep, validator overlap, CI matrix restructure) that don't block
merge. Out-of-scope items stand: the lint-on-edit outside-repo drop is intentional and
security-positive, the double agnix scan is forced by agnix's CLI, and the Codex marketplace's
missing version field is a CLAUDE.md wording nit.
