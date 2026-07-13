---
branch: codex/codex-support
base: main
input: branch
created: 2026-07-13
explain: none — derived from the diff (no explain.md); scenarios grounded in each fix's referent + the repo self-tests
---

# Verify run — Codex support: cross-host hooks, plugin restructure, install/compat validators

No `explain.md` existed, so scenarios were derived from the branch diff (`main...HEAD`): each is
anchored to a fix commit / real referent or to a repo self-test that pins it. Everything here is
read-only (the one write — the `validate-install` exec-bit reproduction — targets the scratchpad
only), so all runnable scenarios auto-ran. Two scenarios that need a real Codex runtime / the pinned
CLIs are honestly recorded as INCONCLUSIVE rather than faked green.

| #   | Type | Pri | Command                                                        | Expected                                                     | Actual                                                           | Verdict      | Evidence                                                                          |
| --- | ---- | --- | -------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------- |
| 1   | cli  | P0  | `doctor.sh --platform` (no value)                              | exit 2 immediately, no hang (`9b230f9`, doctor.sh:24)        | exit 2, prints usage; watchdog never fired                       | PASS         | `exit=2` + `usage: doctor.sh [--platform auto\|claude\|codex\|both]`              |
| 2   | cli  | P0  | `doctor.sh --platform auto` in an adapter-less repo            | checks both + warns, not silent claude (`71bec54`, :202)     | `platform: both` and a `[WARN] platform` ambiguity line          | PASS         | `platform: both` / `[WARN] platform  no .claude/ or .codex/ found`                |
| 3   | test | P0  | `bash scripts/tests/doctor.test.sh`                            | Codex hook missing/nonexec/empty FAIL-or-WARN, ok+trust pass | 22/22 (incl. codex-hook-missing, -nonexec, -ok, -empty, -trust)  | PASS         | `doctor self-test: 22 passed, 0 failed` (was 15 pre-fix)                          |
| 4   | test | P0  | `bash scripts/tests/block-env-access.test.sh`                  | apply_patch terminal + Move-to + padded/CRLF trim all block  | 38/38                                                            | PASS         | `block-env-access self-test: 38 passed, 0 failed`                                 |
| 5   | test | P0  | `bash scripts/tests/hook-runtime.test.sh`                      | fail-closed on missing hook-common.sh; backtick extraction   | 14/14 (incl. missing-hook-common-fails-closed)                   | PASS         | `hook-runtime self-test: 14 passed, 0 failed`                                     |
| 6   | test | P0  | `bash scripts/tests/hooks-in-sync.test.sh`                     | live `.claude/hooks` ≡ templates byte-identical + exec bit   | 22/22                                                            | PASS         | `hooks-in-sync self-test: 22 passed, 0 failed`                                    |
| 7   | cli  | P1  | validate-install exec-bit check (`! -perm -u+x`) — repro       | all-exec → empty (rc 0); one non-exec → non-empty (rc 1)     | all-exec → `''`; after `chmod -x b.sh` → `b.sh`                  | PASS         | `all-exec → PASS` / `one-nonexec → correctly FAILs (rc 1)` (`488bd9a`)            |
| 8   | cli  | P1  | `git check-ignore .agents/plugins/{junk.txt,marketplace.json}` | junk ignored; marketplace.json tracked (`5a433e3`)           | junk → YES; marketplace.json → tracked/allowed                   | PASS         | `junk.txt → YES` / `marketplace.json → tracked/allowed(GOOD)`                     |
| 9   | cli  | P1  | grep `<runtime-dir>` resolution across the 7 dw-quality skills | all 7 define `<runtime-dir>` (`9dc53dd`)                     | 7/7 define it ("resolve `<runtime-dir>` to the absolute … path") | PASS         | ✓ dw-conform/explain/fix/prune/review/risk/verify (first grep was a false alarm)  |
| 10  | cli  | P1  | grep `HOOKS_INSTALLED` in the AGENTS.md template               | placeholder has a home (`aa02368`)                           | present at line 19                                               | PASS         | `19:{{HOOKS_INSTALLED}}`                                                          |
| 11  | cli  | P1  | `bash -n` on all shipped hooks + doctor + validate-install     | every script parses                                          | all parse clean                                                  | PASS         | `all parse clean`                                                                 |
| 12  | test | P1  | `pnpm validate:artifacts`                                      | all self-tests + `.ai/` schema pass                          | OK                                                               | PASS         | `validate:artifacts → OK`                                                         |
| 13  | test | P1  | `pnpm validate:docs`                                           | public docs ↔ skills in sync                                 | OK                                                               | PASS         | `validate:docs → OK`                                                              |
| 14  | test | P1  | `pnpm validate:compat`                                         | cross-host metadata + description budget + version unified   | OK                                                               | PASS         | `17 skills; descriptions 4596/6000; version 0.4.0; Codex >=0.142.0`               |
| 15  | test | P1  | `pnpm validate:manifests`                                      | `claude plugin validate` + marketplace↔plugin version sync   | OK                                                               | PASS         | `validate:manifests → OK`                                                         |
| 16  | test | P1  | `pnpm format`                                                  | prettier clean tree                                          | OK                                                               | PASS         | `format → OK`                                                                     |
| 17  | test | P1  | `pnpm validate:install`                                        | isolated Codex + Claude marketplace/cache smoke              | —                                                                | INCONCLUSIVE | CI-only: needs pinned Codex 0.142.0 + Claude CLIs in a clean env; not run locally |
| 18  | cli  | P1  | real Codex hook firing / patch-path `cwd` resolution (#3)      | lint hook fires on a subdir edit under a live Codex host     | —                                                                | INCONCLUSIVE | no Codex runtime/PreToolUse event in this session — the deferred #3 dependency    |

## Summary

**PASS: 16 · FAIL: 0 · INCONCLUSIVE: 2**

- All three `dw-fix` iterations (blockers · pass 2 · codex:review pass) are exercised: every fix is
  proven either by direct behaviour (rows 1–2, 7–10) or by the self-test that pins it (rows 3–6), and
  the full CI gate is green (rows 12–16).
- No `explain.md` existed — scenarios were derived from the diff, each grounded in a fix commit or a
  repo self-test.
- No mutating scenarios: everything read-only; the one write (row 7) went to the scratchpad.
- The **two INCONCLUSIVE** rows are the honest boundary of this session — they need a real Codex host
  (row 18, the deferred #3 patch-path `cwd`) or the pinned CLIs in a clean env (row 17, the CI-only
  install smoke). They are not failures; they are the same captured-real-Codex-event / CI-environment
  dependency already recorded as deferred in `review.md` and `fix.md`.
- Row 9 note: the first grep reported a false MISSING (capital "Resolve", phrase wraps across lines);
  inspecting the file confirmed all 7 skills define `<runtime-dir>` — a harness false alarm, not a
  code regression.

---

**Next:** consider `dw-risk` — it maps the blast radius and follow-ups for the change you just
verified (the deferred Codex-runtime items #1–#4 are the natural follow-up set).
