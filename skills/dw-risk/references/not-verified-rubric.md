# NOT VERIFIED rubric — grounded vs. unverified, and the silent-pass trap

`dw-risk` reasons about a change without running it, so it must be honest about the limits of
static analysis. Every item in `risk.md` is either **grounded** (anchored to a real referent) or
**NOT VERIFIED** (named, but unconfirmed). This is the analytical analog of `dw-verify`'s
`INCONCLUSIVE`: a first-class outcome, not a failure of the run.

## Grounded

The item traces to something that demonstrably exists in this change or repo, and you can point at
it:

- a blast-radius area → a path in the diff, or a caller found via search / `Read`;
- a migration / env / flag / infra / secret → a name or file referenced in the changed code or a
  config you read;
- a one-way-door → the specific destructive operation in the diff (`DROP`, `remove_column`, a
  delete, a contract change).

A grounded item carries its referent in the row. That's what makes `risk.md` actionable.

## NOT VERIFIED

You could not anchor the item to a referent. Use it — don't guess — when any of these hold:

- **Couldn't reach the evidence** — the signal would live somewhere you can't see from the diff
  (a deploy pipeline, an infra repo, a flag dashboard) and the project doesn't declare it.
- **Ambiguous** — the diff hints at impact (a config read, a renamed symbol) but you can't confirm
  the blast radius or whether a rollback exists.
- **Out of scope of static reading** — runtime-only behaviour (does this migration lock the table
  under load? is that consumer still live?) that only `dw-verify` or a human can settle.

Name the missing referent in the row, so the reader knows exactly what to go check.

## The silent-pass trap (the rule that matters most)

The dangerous failure is not a wrong risk — it's a **falsely empty** one. Writing
"Out-of-code: none" or "fully reversible" when you simply didn't look reads as a clean bill of
health and gets a change waved through.

- An **empty section is honest only if you actually checked and found nothing** — say so:
  "No migrations (checked `db/migrate/`, no new files)."
- If you didn't or couldn't check, the section is **NOT VERIFIED**, not empty.
- Never downgrade a one-way-door to silence because its rollback is unknown. Unknown rollback is a
  finding: "drop of `column Y` — **no rollback identified**, NOT VERIFIED."

## Tie-breakers

- No referent ⇒ never grounded. Mark `NOT VERIFIED`.
- Uncertain reversibility ⇒ treat as a one-way-door until proven otherwise, and say so.
- Partial confidence ⇒ state what you confirmed and what you didn't; don't average it into a vague
  "low risk".
