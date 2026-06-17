# Contributing

Thanks for poking at these skills. This file is the short pointer; the real detail lives where the
agent (and CI) already read it.

## The rules that matter

- **Edit the canonical file.** A skill lives at `skills/<name>/SKILL.md`. Never edit through the
  `plugins/<plugin>/skills/<name>` symlink — that path is a git-tracked symlink back to `skills/`.
- **Match the shape.** Every `SKILL.md` follows one anatomy — see
  [`docs/SKILL-ANATOMY.md`](docs/SKILL-ANATOMY.md). Copy an existing skill that resembles yours and
  keep the section order.
- **Follow the checklist.** The full add-a-skill + version-bump checklist (symlinks, manifests,
  README task-router) lives in [`AGENTS.md`](AGENTS.md) — `CLAUDE.md` is a symlink to it.

## Before you push

```bash
pnpm lint && pnpm format && pnpm validate:manifests
```

CI runs the same gates (agnix lint, prettier, manifest + version-sync validation, trufflehog secrets
scan) on every PR and push to `main`. The gates are listed in [`AGENTS.md`](AGENTS.md).

## Design rationale

The _why_ behind the conventions — persistence in the skill, tracked `.ai/` artifacts,
technology-agnostic procedures, composable-not-chained — is in [`docs/DESIGN.md`](docs/DESIGN.md).
