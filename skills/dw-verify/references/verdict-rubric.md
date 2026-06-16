# Verdict rubric — PASS / FAIL / INCONCLUSIVE

Every scenario ends in exactly one verdict. The rubric exists so the call is
consistent and honest — especially the line between a real PASS and a hopeful one.

## PASS

Actual output matches `Expected`, **and the output is captured in the Evidence
column**. The match should be on the thing that matters: the row returned, the status
code, the assertion that passed — not a vague "no error".

A PASS with an empty Evidence column is not a PASS. If you didn't capture the proof,
you didn't verify it.

## FAIL

Actual output contradicts `Expected` — wrong value, wrong status, an exception, an
assertion that failed. Attach the output that shows the contradiction. A FAIL is a
useful result: it's the artifact doing its job.

## INCONCLUSIVE

You could not produce evidence either way. First-class, not a cop-out — it's the
honest verdict when any of these hold:

- **Couldn't run it** — missing environment, no database / server reachable, an
  unresolved command, missing permission.
- **Ambiguous output** — the command ran but the result doesn't clearly confirm or
  contradict `Expected`.
- **Unsafe to run** — a mutating scenario you couldn't run safely (no transaction /
  sandbox available) and the user didn't confirm.
- **Ungrounded** — the scenario has no real referent to anchor it (e.g. an
  `explain.md` section-E row). Don't run guesses.

Say _why_ it's inconclusive in the Evidence column.

## Tie-breakers

- No captured evidence ⇒ never PASS. Downgrade to INCONCLUSIVE (couldn't prove it) or
  FAIL (it broke).
- Partial match ⇒ FAIL or INCONCLUSIVE, never PASS. "Mostly right" isn't proof.
- Don't average across a run. Each scenario stands on its own verdict; the summary
  just counts them.

## Decision flow (example)

    ran the command?
      no  → INCONCLUSIVE (say why: env / command / unsafe / ungrounded)
      yes → captured output?
              no  → INCONCLUSIVE  (re-run and capture before judging)
              yes → matches Expected?
                      yes → PASS
                      no  → FAIL
