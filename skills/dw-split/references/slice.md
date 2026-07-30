---
slice: "03"
run: YYYYMMDD-parent-run-slug
title: [short descriptive name]
status: ready # ready | doing | done | blocked
blocked_by: ["01", "02"] # [] when it can start immediately
blocks: ["04", "05"]
taken_run: # <new-run-id> — written by `take`, absent until then
---

# 03 — [title]

## What to build

The end-to-end behaviour this slice makes work, from the user's perspective — not a layer-by-layer
implementation list.

## Acceptance criteria

- [ ] [observable outcome]
- [ ] [the project's verify command passes — the real one, read from the project]

## Blocked by

- `01 — [title]` — [why it is a real gate], or "None — can start immediately".

## Anchors

- `path/to/file.rb:42` — [what it is and why this slice cares]
