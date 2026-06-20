#!/usr/bin/env bash
# Validate the repo's .ai/ work artifacts against the structural schema, then
# assert the golden-fixture contract: good/ pairs pass, malformed/ pairs fail,
# and plan-status.sh --check agrees on the good PLAN fixtures. Backs
# `pnpm validate:artifacts` and the validate-ai-artifacts CI workflow.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VALIDATOR="$ROOT/plugins/dw-planning/scripts/validate-ai-artifacts.sh"
PLAN_STATUS="$ROOT/plugins/dw-planning/scripts/plan-status.sh"
FIX="$ROOT/tests/fixtures/ai-artifacts"

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
echo "Checking good/ fixtures (expect pass)..."
for d in "$FIX"/good/*/; do
  [ -d "$d" ] || continue
  if "$VALIDATOR" --all "$d" >/dev/null 2>&1; then
    echo "OK  good/$(basename "$d")"
  else
    echo "::error::good fixture should pass but failed: $(basename "$d")"
    FAILED=1
  fi
done

echo
echo "Checking malformed/ fixtures (expect fail)..."
for d in "$FIX"/malformed/*/; do
  [ -d "$d" ] || continue
  if "$VALIDATOR" --all "$d" >/dev/null 2>&1; then
    echo "::error::malformed fixture should fail but passed: $(basename "$d")"
    FAILED=1
  else
    echo "OK  malformed/$(basename "$d") (correctly rejected)"
  fi
done

echo
echo "Checking plan-status.sh --check on good PLAN fixtures..."
while IFS= read -r plan; do
  [ -n "$plan" ] || continue
  if "$PLAN_STATUS" --check "$plan" >/dev/null 2>&1; then
    echo "OK  plan-status --check: ${plan#"$FIX"/}"
  else
    echo "::error::plan-status --check failed on good fixture: $plan"
    FAILED=1
  fi
done < <(find "$FIX/good" -name PLAN.md | sort)

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All artifact checks passed."
else
  echo "Artifact validation FAILED."
fi
exit $FAILED
