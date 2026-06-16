---
name: dw-handoff
description: >-
  Compact the current conversation into a handoff document under `.ai/handoffs/`
  so another agent — a fresh Claude Code session, Codex, or a teammate — can
  continue without re-reading the transcript. Links back to the active
  `.ai/runs/` run when one exists. Use when wrapping up a session, pausing work,
  or preparing context for another agent. Trigger phrases: "session handoff",
  "handoff", "dw-handoff", "summarise for next session", "prepare context for
  another agent", "wrap up so someone can pick this up".
argument-hint: "What will the next session focus on?"
disable-model-invocation: true
---

# dw-handoff — session handoff

Write a continuation document so the next agent — fresh Claude Code session,
Codex, or a teammate's agent — can resume without re-reading the whole
transcript.

## Output location

Save to `.ai/handoffs/<YYYYMMDD-HHMM>.md`. `.ai/` is tracked in git — handoffs
are real work documentation, committed alongside the code (not throwaway).
Create the directory if missing:

```bash
mkdir -p .ai/handoffs
```

Filename uses local time. Example: `.ai/handoffs/20260616-1430.md`.

## Link the active run (back-pointer)

If the work belongs to a run under `.ai/runs/`, link it so the next agent lands
on the plan, not just the prose:

1. Get the current branch (`git rev-parse --abbrev-ref HEAD`).
2. Glob `.ai/runs/*/` and match the run whose frontmatter `branch` equals the
   current branch (the same match `dw-resume` uses).
3. Put that run's `PLAN.md` (and `SPEC.md`) in **Pointers** as a back-pointer.

If `.ai/runs/` is absent or has no run for this branch, say so in Pointers
("no active run") and continue — the handoff still stands on its own.

## What to include

- **Goal** — one sentence: what we're trying to accomplish (use `$ARGUMENTS` — the next session's focus — if provided)
- **Current state** — what's been done, what's working, what's broken
- **Open questions** — decisions the next agent needs to make or surface to the user
- **Next steps** — ordered list of concrete actions to take next
- **Suggested skills** — Claude Code skills the next agent should invoke (e.g., `dw-resume`, `dw-build`, `git-workflow`, `debugging-and-error-recovery`)
- **Pointers** — references to existing artifacts (active run, specs, plans, ADRs, PRs, issues) by path or URL. Don't duplicate their content
- **Gotchas / context** — non-obvious things the next agent needs to know (env quirks, dependency versions, recent failures, etc.)

## What to leave out

- Don't re-summarise content already in committed files, PR descriptions, specs, plans, or ADRs. Reference them by path
- Redact secrets, API keys, PII, internal URLs that shouldn't be shared
- Skip narrative play-by-play of the conversation. Focus on actionable state

## Document template

```markdown
# Handoff — <YYYY-MM-DD HH:MM>

## Goal

<one sentence>

## Current state

- <what's done>
- <what's in progress>
- <what's blocked>

## Open questions

- <decision needed>

## Next steps

1. <action>
2. <action>
3. <action>

## Suggested skills

- `<skill-name>` — <why>

## Pointers

- run: `.ai/runs/<id>/PLAN.md` (active run — or "none")
- spec: `.ai/runs/<id>/SPEC.md`
- PR: <url or path>
- relevant files: `<path:line>`

## Gotchas

- <non-obvious context>
```

## After writing

Tell the user:

> Handoff saved to `.ai/handoffs/<filename>`. Open a new Claude Code session and run:
>
> ```
> Read the handoff at .ai/handoffs/<filename> and continue from there.
> ```
