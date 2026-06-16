---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
explain: .ai/verify/my-feature-branch/explain.md # or "none — derived from diff"
---

# Verify run — [title of the change]

Results of running the scenarios from `explain.md` section C. Each row carries the
actual output and a verdict; PASS and FAIL always cite evidence. `dw-verify` writes
this table row by row.

| #   | Type   | Pri | Command                      | Expected            | Actual                   | Verdict      | Evidence                     |
| --- | ------ | --- | ---------------------------- | ------------------- | ------------------------ | ------------ | ---------------------------- |
| 1   | [type] | P0  | `[project-resolved command]` | [observable result] | [what actually happened] | PASS         | [output excerpt / log path]  |
| 2   | [type] | P1  | `[command]`                  | [expected result]   | [actual result]          | FAIL         | [output excerpt]             |
| 3   | [type] | P2  | `[command]`                  | [expected result]   | —                        | INCONCLUSIVE | [why: missing env / not run] |

- **Type** — `db` · `http` · `cli` · `console` · `test` · `browser` (carried from `explain.md`).
- **Pri** — `P0` core path · `P1` important behaviour / main edge · `P2` secondary.
- **Actual** — what the command actually produced. For INCONCLUSIVE, leave it `—`.
- **Verdict** — `PASS` · `FAIL` · `INCONCLUSIVE`. See `verdict-rubric.md`.
- **Evidence** — the captured proof: the decisive output line, the status code, or a
  path to the full log. **Never empty for PASS or FAIL.** For INCONCLUSIVE, say why.

## Summary

**PASS: [n] · FAIL: [n] · INCONCLUSIVE: [n]**

- [note any mutating scenarios left unrun pending confirmation]
- [note any scenario derived from the diff because no `explain.md` existed]

---

**Next:** consider `dw-risk` — it maps the blast radius and follow-ups for the change
you just verified.
