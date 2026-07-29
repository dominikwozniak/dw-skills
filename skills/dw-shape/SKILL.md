---
name: dw-shape
description: >-
  Turn a request or a finished `dw-grill` conversation into one durable `CHANGE.md` under
  `.ai/work/` — goal, decisions taken, a task checklist, and anchors in real files. Depth scales
  with size: a small change gets a goal and two checkboxes, not a spec. The solo lane's single
  planning artifact, read back by `dw-next` after a `/clear`. Use when starting work on a private
  project, or when someone says "shape this", "write this up", "let's plan this out", or invokes
  "dw-shape". Prefer this over `dw-spec` + `dw-plan` in a solo repo — one file instead of three, no
  status table.
argument-hint: "What change are we shaping?"
---

# dw-shape — one file, then build

The solo lane's whole planning step. It writes **one** `CHANGE.md`: enough to survive a week away
from the project and a `/clear`, and no more. There is no separate spec, no separate plan, no status
table with commit SHAs — those earn their keep when other people read them, and here nobody does.

This skill does **not** interview you. If the idea is still fuzzy, run `dw-grill` first and come back
— synthesis and interrogation are different jobs, and mixing them produces a document arguing with
itself.

## Output location

Write to `.ai/work/<slug>/CHANGE.md`. `.ai/` is tracked in git, so the file survives a `/clear` and a
week-long gap between sessions — but this one is **working scaffolding, not a deliverable**:
`dw-land` deletes it at merge after promoting anything durable out of it. That split is deliberate;
decisions belong in `docs/decisions/`, not in a spec nobody will reopen.

1. **Don't start a second change on the same branch.** Look for an existing one first:
   `grep -l "^branch: $(git branch --show-current)\$" .ai/work/*/CHANGE.md 2>/dev/null`. If one turns
   up and its `status:` isn't `landed`, **continue that file** — only open a new change for genuinely
   separate work. When unsure, ask.
2. **Derive the slug, don't invent it:**
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slugify.sh" slug "<short description>"`. Same script the
   whole catalog uses, so casing never drifts. (`${CLAUDE_PLUGIN_ROOT}` is the env var Claude Code
   substitutes to this plugin's install dir.)

## Workflow

### 1. Read the project, don't assume it

- The request (it may arrive as `$ARGUMENTS`) plus anything settled in the conversation.
- `CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` for the test, lint and typecheck commands and the git
  conventions. If none are declared, read the manifests (`package.json` scripts, `Gemfile` + `bin/`,
  `Makefile`, `pyproject.toml`, …) — their presence is what detects the stack. Never name a command
  you haven't seen.
- `CONTEXT.md` and `docs/decisions/` if the project has them — a term already defined or a decision
  already taken is not up for re-litigation, and reusing the established word is free.
- The **real sibling patterns** this change should follow. Confirm each with Read or grep; these
  become the anchors.

### 2. Size it, then match the depth to the size

Judge the change honestly, then write accordingly — this is the step that keeps the lane light:

- **Small** (one file, one obvious edit, no new concept): a goal and one or two checkboxes. Skip
  Decisions and Anchors entirely. Do not manufacture ceremony for a rename.
- **Normal** (a few files, one seam): a goal, the decisions actually taken, three to six tasks,
  the anchors.
- **Large** (touches several layers, or you can't see the end): still one file — but say plainly that
  it's large and offer to cut it down to the first genuinely shippable piece. A change you can't
  finish is worse than a smaller one you can.

If it stays too big to hold, this is the honest moment to reach for the team lane's `dw-split`
instead of pretending a checklist covers it.

### 3. Cut the tasks as thin vertical slices

Each task is a **complete narrow path**, not a layer. "Add the column, the query and the read path
for one field" is a task; "add all the migrations" is not. Each one should be independently
committable, leave the project green, and be small enough that a fresh session could do it alone.

Order them so each builds on the last — but treat that order as a **hint, not a gate**. If task 3 is
obviously doable before task 2, do it. Dependencies here are there to help you pick, never to refuse.

### 4. Write the file, then check it back

Write `CHANGE.md` from the shape in `references/CHANGE.md`. Then read the goal and the task list back
to the user in a few lines and ask whether the breakdown is right — wrong granularity is much cheaper
to fix now than after two commits. **Wait for that confirmation before building anything.**

Going straight from here to `dw-next` is the normal path. There is no intermediate approval artifact
by design.

**Next:** `dw-next` to build the first task, or `dw-grill` if that read-back exposed something still
undecided.

## The CHANGE shape

`references/CHANGE.md` is the exact shape to copy — frontmatter (`change / branch / created /
status`) plus Goal · Decisions · Tasks · Anchors · Notes. Keep it lean: this is a note to your
future self, not documentation. Anything that is genuinely durable knowledge belongs in
`docs/decisions/` or `CONTEXT.md`, which is what `dw-land` promotes it to.
