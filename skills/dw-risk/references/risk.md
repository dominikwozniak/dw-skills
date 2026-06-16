---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
sources: explain.md, verify-run.md, review.md, conform.md # which neighbours fed this; "none — derived from diff" if standalone
---

# Risk — [title of the change]

Pre-deploy risk assessment for this change: what it touches, what it needs beyond the code merge,
and how to undo it. Every row is grounded in a real referent; anything that couldn't be grounded
is marked `NOT VERIFIED` rather than left to look safe. `dw-risk` writes this before merge/deploy.

## (a) Blast radius

What the change touches, by how far the impact reaches.

| Area                | Tier      | What changes                         | Referent           |
| ------------------- | --------- | ------------------------------------ | ------------------ |
| `[path/module]`     | core      | [the change's own path]              | [path:line]        |
| `[caller / shared]` | secondary | [downstream effect on adjacent code] | [caller path:line] |
| `[path/module]`     | isolated  | [self-contained, no downstream]      | [path]             |

- **Tier** — `core` (breaks the feature if wrong) · `secondary` (callers / shared / adjacent) ·
  `isolated` (contained, no reach). See `blast-radius-taxonomy.md`.
- **Referent** — the path / line / caller that grounds the row. No referent ⇒ `NOT VERIFIED`.

## (b) Out-of-code

Everything that must happen **besides merging the code**.

| Kind      | Item            | Action required                     | Referent                    | One-way-door?                  |
| --------- | --------------- | ----------------------------------- | --------------------------- | ------------------------------ |
| migration | [add column X]  | [run before deploy]                 | [db/migrate/…]              | no — reversible down-migration |
| migration | [drop column Y] | [run during deploy]                 | [db/migrate/…]              | **YES** — data lost, see (c)   |
| env       | [NEW_VAR]       | [set in every env before deploy]    | [config / .env.…]           | no                             |
| flag      | [feature_x]     | [ship off; enable after smoke test] | [path:line]                 | no                             |
| infra     | [queue / cron]  | [provision before deploy]           | [*.tf / manifest]           | no                             |
| secret    | [API_KEY]       | [add to the secret store]           | [path:line]                 | no                             |
| [kind]    | [item]          | —                                   | [none found / NOT VERIFIED] | —                              |

- **Kind** — `migration` · `env` · `flag` · `infra` · `secret`.
- Empty only if you confirmed there's nothing — otherwise the row is `NOT VERIFIED`.

## (c) Follow-ups & rollback

- **Follow-ups (after deploy):** [backfill / monitor metric X / announce the breaking change / flip
  the flag once healthy]
- **Rollback:** [per reversible piece: revert the commit (+ run the down-migration for `column X`)]
- **One-way-doors (no clean undo):** [drop of `column Y` — data is gone; restore needs a backup. OR
  "none — fully reversible"]

---

Any section above that couldn't be anchored to a real referent is **NOT VERIFIED** — resolve those
by hand before merge/deploy. See `not-verified-rubric.md`. An empty section is honest only if you
actually checked and found nothing.
