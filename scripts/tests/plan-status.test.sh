#!/usr/bin/env bash
# Self-test for plan-status.sh: the frontmatter `status:` scalar is derived from the table's
# Status column. Covers the precedence rule (blocked > done > doing > todo), the in-place rewrite
# (currently the only untested path), --check report-only (drift => exit 1, writes NOTHING),
# idempotency, and the error cases. Throwaway PLAN.md files built at run time — no fixtures.
#
# Run standalone (`bash scripts/tests/plan-status.test.sh`) or via scripts/validate-artifacts.sh.
# Exit 0 iff every case behaves as expected. bash 3.2 / macOS + BSD-sed safe.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PLAN_STATUS="$ROOT/scripts/runtime/plan-status.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/plan-status-selftest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }

fm_status() { sed -n 's/^status:[[:space:]]*//p' "$1" | head -1; }

# mk_plan <frontmatter-status> [row-status...] — a PLAN.md with a status table of the given rows.
mk_plan() {
  fm="$1"; shift
  d="$(mktemp -d "$tmp/plan.XXXXXX")"; p="$d/PLAN.md"
  {
    printf '%s\n' '---' 'run: x' 'spec: SPEC.md' "status: $fm" '---' ''
    printf '%s\n' '| Phase | Step | Title | Status | Commit |' '| --- | --- | --- | --- | --- |'
    i=0
    for s in "$@"; do
      i=$((i + 1))
      if [ "$s" = "done" ]; then c="abc1234"; else c=""; fi
      printf '| p | 1.%s | t | %s | %s |\n' "$i" "$s" "$c"
    done
  } >"$p"
  echo "$p"
}

# derive_eq <name> <expected> [row-status...] — rewrite a deliberately-stale plan, then the
# rewritten frontmatter must read <expected> (exercises derivation AND the in-place rewrite).
derive_eq() {
  name="$1"; want="$2"; shift 2
  seed=todo; [ "$want" = todo ] && seed=blocked   # seed != want so a rewrite must happen
  p=$(mk_plan "$seed" "$@")
  "$PLAN_STATUS" "$p" >/dev/null 2>&1
  got=$(fm_status "$p")
  if [ "$got" = "$want" ]; then note_pass "$name"; else note_fail "$name" "derived '$got' want '$want'"; fi
}

echo "derivation + rewrite (precedence: blocked > done > doing > todo):"
derive_eq "all-todo"          todo    todo todo
derive_eq "one-doing"         doing   todo doing
derive_eq "one-done"          doing   done todo
derive_eq "all-done"          done    done done
derive_eq "blocked-beats-done" blocked done blocked done
derive_eq "blocked-alone"     blocked todo blocked
derive_eq "empty-table"       todo

echo "--check (report-only):"
p=$(mk_plan done done done)
if "$PLAN_STATUS" --check "$p" >/dev/null 2>&1; then note_pass "check-in-sync"; else note_fail "check-in-sync" "expected exit 0"; fi

p=$(mk_plan todo done done)             # frontmatter todo but table implies done -> drift
before=$(cat "$p")
"$PLAN_STATUS" --check "$p" >/dev/null 2>&1; rc=$?
after=$(cat "$p")
if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
  note_pass "check-drift-detected-no-write"
else
  note_fail "check-drift-detected-no-write" "rc=$rc / file mutated=$([ "$before" = "$after" ] && echo no || echo yes)"
fi

echo "idempotency:"
p=$(mk_plan todo done done)
"$PLAN_STATUS" "$p" >/dev/null 2>&1                 # first rewrite: todo -> done
first=$(fm_status "$p")
"$PLAN_STATUS" "$p" >/dev/null 2>&1; rc=$?          # second: already done, no change
second=$(fm_status "$p")
if [ "$rc" -eq 0 ] && [ "$first" = "done" ] && [ "$second" = "done" ]; then
  note_pass "rewrite-idempotent"
else
  note_fail "rewrite-idempotent" "rc=$rc first='$first' second='$second'"
fi

echo "errors (expect non-zero exit):"
# frontmatter status present but no status table
d="$(mktemp -d "$tmp/p.XXXXXX")"; notable="$d/PLAN.md"
printf '%s\n' '---' 'run: x' 'spec: SPEC.md' 'status: todo' '---' '' '# no table' >"$notable"
if "$PLAN_STATUS" "$notable" >/dev/null 2>&1; then note_fail "err-no-table" "expected non-zero"; else note_pass "err-no-table"; fi

# status table present but no frontmatter status: line
d="$(mktemp -d "$tmp/p.XXXXXX")"; nostatus="$d/PLAN.md"
printf '%s\n' '---' 'run: x' 'spec: SPEC.md' '---' '' \
  '| Phase | Step | Title | Status | Commit |' '| --- | --- | --- | --- | --- |' \
  '| p | 1.1 | t | done | abc1234 |' >"$nostatus"
if "$PLAN_STATUS" "$nostatus" >/dev/null 2>&1; then note_fail "err-no-fm-status" "expected non-zero"; else note_pass "err-no-fm-status"; fi

if "$PLAN_STATUS" "$tmp/does-not-exist.md" >/dev/null 2>&1; then note_fail "err-missing-file" "expected non-zero"; else note_pass "err-missing-file"; fi

echo
echo "plan-status self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
