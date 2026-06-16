# Blast-radius taxonomy & out-of-code checklist

The vocabulary behind `risk.md` sections (a) and (b): how to tier impact, what to look for in each
out-of-code kind, and which signals mark a one-way-door. The `dw-risk` body holds the procedure;
this file holds the encyclopaedia.

## Impact tiers (section a)

Bucket each touched area by how far its impact reaches — not by how big the diff is.

| Tier        | Meaning                                                         | Grounded by                                  |
| ----------- | --------------------------------------------------------------- | -------------------------------------------- |
| `core`      | The change's own path. If this is wrong, the feature is broken. | The changed file/function itself.            |
| `secondary` | Callers, shared modules, adjacent features routing through it.  | A caller / importer you found (search/Read). |
| `isolated`  | Self-contained; nothing downstream depends on it.               | Absence of callers — confirmed, not assumed. |

`isolated` is a claim, not a default: you only earn it by checking for callers and finding none.
If you didn't check, the area is `NOT VERIFIED`, not `isolated`.

## Out-of-code checklist (section b)

For each kind, the question and the signals that betray it in a diff. Read-only — detect, never run.

- **Migrations** — _Does the schema or data change?_ Signals: files under a migrations dir, DDL
  (`CREATE` / `ALTER` / `DROP`), data backfills, index changes. Note ordering vs. the deploy
  (before / during / after) and whether it locks a table.
- **Env vars** — _Does the code read a new/renamed config value?_ Signals: a new key read from the
  environment, a changed `.env.example`, a config object gaining a field. Every env it must be set
  in is a manual step before deploy.
- **Feature flags** — _Is new behaviour gated, or a gate removed?_ Signals: a flag check in the
  diff, a flag added/removed in a flag config. Note the intended default and when it flips on.
- **Infra** — _Does running this need something new in the environment?_ Signals: changed IaC
  (`*.tf`, k8s, `docker-compose`), new queue / cron / worker, scaling or memory needs, DNS / CDN /
  bucket changes.
- **Secrets** — _Does it need a new credential?_ Signals: a new API key / token / cert referenced.
  These go in the secret store, never the diff — flag any secret that looks committed as a finding.

## One-way-door signals (sections b & c)

Steps that **reverting the code does not undo**. Each must be named in `risk.md`, with a rollback
plan or an explicit "none":

- a dropped / renamed column or table; any destructive (non-reversible) migration;
- data deleted, truncated, or backfilled in place (the old values are gone);
- a removed / renamed endpoint, or a changed request/response contract clients already use;
- a published event / message-schema change, or anything a downstream consumer has already read by
  the time you'd roll back;
- a destructive infra action (a deleted resource, a non-versioned config overwrite).

Reversible-by-default (call out only if the rollback is non-obvious): additive columns with a
down-migration, additive endpoints, flags shipped off, new env/secrets.

## Per-stack examples (illustrative only — never logic)

The kinds above are stack-agnostic; how they _surface_ depends on the project. These are
_examples_ of where to look — the real signal always comes from the project in front of you.

- _Example (Rails):_ migrations in `db/migrate/*.rb`; a `remove_column` / `drop_table` is a
  one-way-door; flags often via a gem or `ENV`; secrets in credentials / a vault.
- _Example (Node):_ migrations via the ORM's migrate dir; env from `process.env` + `.env.example`;
  infra in `*.tf` or a compose file.

Do not branch logic on these. They illustrate the referent → finding pattern, nothing more.
