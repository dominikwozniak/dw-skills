---
branch: codex-cross-agent-support
base: main
created: 2026-06-23
sources: review.md
---

# Fix log — codex-cross-agent-support

All 4 findings from `review.md` applied, worst-first, one logical commit each. No blockers (review
was `approve-with-comments`); no irreversible actions. `dw-fix` treats — it does not re-grade.

## Applied

| Severity | Location                          | Finding                                                                     | Fix commit |
| -------- | --------------------------------- | --------------------------------------------------------------------------- | ---------- |
| medium   | `AGENTS.md` (add-a-skill step 2)  | Checklist never told contributors to create the `.codex/skills/<name>` link | `6510d13`  |
| medium   | `scripts/validate-manifests.sh`   | No CI assertion that `.codex/skills/` stays in sync with `skills/`          | `dfd10b8`  |
| low      | `scripts/install-codex.sh:35`     | `installed` counter incremented even when `ln` failed (could overcount)     | `6f59fc8`  |
| low      | `scripts/validate-manifests.sh:4` | Stale file-header comment ("each plugin's" → "each consuming skill's" dir)  | `193ed86`  |

## Deferred

— none —

## Verification run per fix (read-only / safe)

- `6510d13` — `pnpm validate:docs` ✓, `pnpm format` ✓; agnix exits 0 with adequate memory (local
  `pnpm lint` OOMs at the script's 8GB ceiling — environment, not content).
- `dfd10b8` — `bash -n` ✓; `pnpm validate:manifests` exits 0, new check validates all 17 `.codex`
  links.
- `6f59fc8` — `bash -n` ✓; ran `install-codex.sh` to a throwaway dest: 17 linked, idempotent re-run.
- `193ed86` — `bash -n` ✓; `pnpm validate:manifests` still exits 0.

## Next

Medium / low only — no blocker was ever in play, so a fresh full re-review is optional, not a gate.
**Next:** `dw-explain` → `dw-verify` to prove the change still runs. Re-run `dw-review` only if you
want a fresh verdict on these fixes.
