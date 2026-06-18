---
name: dw-git
description: >-
  One skill for every git operation in this project — commit, push, open PR,
  sync, branch, stash — applying the repo's own conventions instead of generic
  defaults. Reads `## Git conventions` from `CLAUDE.local.md` (commit format,
  default branch, trailer policy, signing) and falls back to documented defaults
  when absent. Stages by name (never `git add -A`), keeps history atomic, and
  refuses dangerous operations. Use when committing, pushing, opening a pull
  request, rebasing onto the default branch, creating a branch, or stashing.
  Trigger phrases: "commit", "push", "open PR", "create pull request", "sync with
  main", "new branch", "stash my work", "dw-git". Use this for any git intent —
  even when the user just says "commit this" or "push" without naming the skill.
  Prefer it over ad-hoc git commands so the project's conventions are applied
  consistently.
argument-hint: "Which git op? e.g. commit, push, open PR, sync, branch, stash"
---

# dw-git — all git ops, by the project's own conventions

One skill, every git operation. The point is consistency: read the conventions
the repo already documents and apply them, rather than guessing per-commit. This
is the skill the rest of the dw-\* family points at when it needs git done right
(`dw-handoff`, `dw-explain`, `dw-bootstrap` all reference it).

## What it reads

Before any operation, read `CLAUDE.local.md` (repo root) if present and look for a
`## Git conventions` block. Those values **override** the defaults below —
commit format, default branch, branch naming, trailer policy, PR title format,
rebase-vs-merge, signing. If there's no `CLAUDE.local.md` or no such block, use
the documented defaults.

dw-git writes **no `.ai/` artifact** — its durable output is the git history
itself (commits, branches, the opened PR). It's an action skill, not a
document-producing one.

## Operations

### commit

**Defaults** (overridden by `## Git conventions`):

- Format: `[TICKET-XXX] type: description` if the branch matches `^[A-Z]+-\d+`,
  else `type: description`.
- Subject: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  type, imperative, lowercase, no trailing period, ≤72 chars.
- Body: what + why for non-trivial changes; omit for trivial ones.
- **NO** `Co-Authored-By` trailer, **NO** "Generated with Claude Code" footer
  (unless the conventions say otherwise).
- One logical change per commit — split when session work spans concerns.

**Workflow:**

1. `git status --short` — see everything.
2. Classify: session work (created/edited this conversation) vs pre-existing /
   unrelated. **Stage session work by name** (`git add path1 path2`); never
   `git add .` / `git add -A` unless the user explicitly asks.
3. Exclude sensitive files (`.env`, credentials, keys) — warn, don't stage.
4. `git diff --staged` — review what's actually staged.
5. Ticket key from branch: `git branch --show-current | grep -oE '^[A-Z]+-[0-9]+'`.
   If found, prefix `[KEY] `.
6. Commit — `-m` for the subject, repeat `-m` for the body (no heredoc needed for a
   short body). Use plain `git commit` and follow the project's signing convention
   from `CLAUDE.local.md`; don't add `-S` or run `git config` to change signing.
   Surface an error only if the commit genuinely fails.
7. `git log --oneline -1` — confirm.

### push

**Defaults:**

- Plain `git push` for feature branches.
- Force-push is blocked by `block-dangerous-git.sh` when installed; otherwise
  refuse it manually.
- Pushing to `main` / `master` / `develop` needs explicit confirmation first.

**Workflow:**

1. `git branch --show-current`. If it's a protected branch, confirm before pushing.
2. Upstream check: `git rev-parse --abbrev-ref @{u} 2>/dev/null`.
3. No upstream → `git push -u origin "$(git branch --show-current)"`; else `git push`.
4. Report the result.

### PR — "open PR", "create pull request"

**Defaults:**

- Title: same format as the commit subject.
- Body: summary + test plan derived from the commits since the base branch; **no**
  attribution footer.
- Use `.github/PULL_REQUEST_TEMPLATE.md` as the body skeleton if it exists.
- Create via `gh pr create` — never the web UI.

**Workflow:**

1. Push the branch first if it isn't pushed (see **push**).
2. Base branch: from `## Git conventions`, else
   `git symbolic-ref --short refs/remotes/origin/HEAD`.
3. Build the body (PR template if present, else `## Summary` bullets +
   `## Test plan` checklist).
4. `gh pr create --title "..." --body "..."`; print the PR URL.

### sync — "sync with main", "rebase"

**Defaults:** rebase, not merge. Refuse on a dirty tree — ask the user to commit
or stash first.

```bash
git fetch origin
git rebase origin/<default-branch>
```

On conflicts: report them and **stop** — do not auto-resolve.

### branch — "new branch", "switch branch"

Use `git switch -c` (not `git checkout -b`). Name `<ticket>-<slug>` or
`<ticket>/<slug>`; prompt for the ticket key + slug if not given.

### stash — "stash my work"

Always with a message: `git stash push -m "<what's being saved>"`. Never bare
`git stash`.

## Notes

- Defaults assume `block-dangerous-git.sh` is installed (via `dw-bootstrap`). If
  it isn't, manually refuse the same patterns (force-push, hard-reset, `clean -f`).
- Modern verbs throughout: `git switch` / `git restore` over `git checkout`.

**Next:** `dw-review` to weigh the diff before opening the PR, or `dw-handoff` to
pack the session for the next agent once the work is pushed.
