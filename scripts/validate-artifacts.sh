#!/usr/bin/env bash
# Validate the repo's .ai/ work artifacts against the structural schema, then run every
# runtime-script self-test under scripts/tests/ (synthetic cases that prove each shipped
# script behaves — the validator accepts/rejects artifacts, slugify/plan-status derive
# correctly). Backs `pnpm validate:artifacts` and the validate-ai-artifacts CI workflow.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VALIDATOR="$ROOT/scripts/runtime/validate-ai-artifacts.sh"

FAILED=0

if [ ! -x "$VALIDATOR" ]; then
  echo "::error::missing or non-executable validator: $VALIDATOR"
  exit 1
fi

echo "Validating repo .ai/ artifacts..."
if "$VALIDATOR" --all "$ROOT"; then
  echo "OK  repo .ai/ artifacts valid"
else
  echo "::error::repo .ai/ artifacts failed schema validation"
  FAILED=1
fi

echo
echo "Running runtime-script self-tests..."
for t in "$ROOT"/scripts/tests/*.test.sh; do
  [ -f "$t" ] || continue
  echo "• $(basename "$t")"
  bash "$t" || FAILED=1
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All artifact checks passed."
else
  echo "Artifact validation FAILED."
fi
exit $FAILED
