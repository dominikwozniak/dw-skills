#!/usr/bin/env bash
set -uo pipefail
failed=0
for target in claude-code codex; do
  echo "agnix target: $target"
  out="$(NODE_OPTIONS=--max-old-space-size=8192 node_modules/.bin/agnix --target "$target" . 2>&1)"; code=$?
  printf '%s\n' "$out"
  if printf '%s' "$out" | grep -qi 'terminated abnormally'; then
    echo "::error::agnix terminated abnormally for $target" >&2
    failed=1
  elif [ "$code" -ne 0 ]; then
    failed=1
  fi
done
exit "$failed"
