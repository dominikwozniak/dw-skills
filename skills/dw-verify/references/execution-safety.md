# Execution safety — read-only vs mutating

`dw-verify` runs scenarios against whatever environment the session can reach. The
guard that keeps that safe is one classification, applied to every scenario before it
runs: **does this change state?**

## Classify first

| Type      | Read-only (auto-run)                        | Mutating (confirm first)                               |
| --------- | ------------------------------------------- | ------------------------------------------------------ |
| `db`      | `SELECT`, `EXPLAIN`, read-only views        | `INSERT` / `UPDATE` / `DELETE`, `ALTER`, `DROP`, DDL   |
| `http`    | `GET`, `HEAD`                               | `POST` / `PUT` / `PATCH` / `DELETE`                    |
| `cli`     | commands that only read / report            | anything that writes files, calls a write API, deletes |
| `console` | reads, pure function calls                  | calls that persist, enqueue, or send                   |
| `test`    | the suite against an isolated DB / fixtures | tests that hit a shared real environment               |
| `browser` | loading a page, reading rendered state      | submitting a form, an action that persists             |

When in doubt, treat it as mutating and confirm.

## Run mutating scenarios safely

The goal: prove the behaviour without leaving a trace on real data. Prefer, in order,
whichever the project supports. The snippets below are **examples** — the real command
always comes from the project (see the SKILL's command-discovery section).

### db — wrap in a transaction and roll back

Run the mutation, observe the result, then roll back so nothing persists.

_Example (Postgres):_

    BEGIN;
    UPDATE users SET status = 'active' WHERE id = 1;     -- the mutation under test
    SELECT status FROM users WHERE id = 1;               -- observe: 'active'
    ROLLBACK;                                            -- nothing persisted

_Example (Rails console):_

    ActiveRecord::Base.transaction do
      user.activate!
      puts user.reload.status        # observe
      raise ActiveRecord::Rollback   # nothing persisted
    end

Or run against a disposable / test database rather than the real one.

### http — prefer GET, sandbox the rest

Prove with a `GET` where you can. For a `POST` / `PUT` / `DELETE`, point at a staging
or local base URL, or create-then-delete a throwaway record — and confirm with the
user first.

_Example:_

    # read-only proof, safe to auto-run
    curl -i http://localhost:3000/users/1

    # mutating — confirm, and target a sandbox base URL, not production
    curl -i -X POST "$SANDBOX_URL/users" -d 'email=throwaway@example.test'

### cli — dry-run and sandboxes

Use a `--dry-run` flag if the command has one, run inside a temp directory, or point
the command at a sandbox config. Confirm before anything destructive.

## The non-negotiables

- Never silently mutate real data to make a scenario pass.
- If a mutating scenario can't be run safely and the user doesn't confirm, the verdict
  is `INCONCLUSIVE`, not a guessed PASS.
- Capture output for everything you do run — no evidence, no PASS.
