# {{PROJECT_NAME}} — agent instructions

Shared project instructions for Codex, Claude Code, and teammates.

## Workflow

- Persistent artifacts live in tracked `.ai/` directories.
- Use `dw-spec` → `dw-plan` → `dw-build`, then `dw-review` and `dw-verify`.
- Use `dw-resume` after a context reset and `dw-handoff` when transferring work.

## Commands

- **Test command**: {{TEST_COMMAND}}
- **Lint command**: {{LINT_COMMAND}}
- **Typecheck command**: {{TYPECHECK_COMMAND}}

## Hooks installed

{{HOOKS_INSTALLED}}

## Architecture and project specifics

- **Stack**: {{STACK}}
- **Domain**: _(one-line summary or link to project documentation)_
- **Key directories**: _(business logic, adapters, tests)_
- **Deployment target**: _(how and where the project ships)_

## Git conventions

- **Default branch**: {{DEFAULT_BRANCH}}
- **Commit format**: `[TICKET-123] type: description` when the branch carries a ticket; otherwise
  `type: description`.
- One logical change per commit. Stage paths explicitly. Never force-push without explicit consent.
