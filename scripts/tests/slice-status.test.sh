#!/usr/bin/env bash
# Self-test for slice-status.sh: the frontier is what dw-split and dw-resume READ to decide
# what to do next, and a one-sided edge silently hides a dependency — so both the structural
# checks and the frontier derivation need pinning, not trusting.
#
# Structure is base+mutation, like validate-ai-artifacts.test.sh: `mk_graph` builds one
# canonical 4-slice graph (01 done, blocking 02 and 03; 03 also blocked by 04; 04 free), so
# the healthy frontier is exactly "02 04". Each malformed case is that graph through a
# one-line sed defect, so the defect is the diff.
#
# Run standalone (`bash scripts/tests/slice-status.test.sh`) or via scripts/validate-artifacts.sh.
# Exit 0 iff every case behaves as expected. bash 3.2, and portable across BSD and GNU sed —
# see `patch` below for the in-place-edit trap that made the first version pass only on macOS.
set -uo pipefail
export LC_ALL=C

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SLICE_STATUS="$ROOT/scripts/runtime/slice-status.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/slice-status-selftest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }

# slice <id> <title> <status> <blocked_by> <blocks> — one slice file on stdout.
slice() {
  cat <<EOF
---
slice: "$1"
run: 20260101-fixture
title: $2
status: $3
blocked_by: $4
blocks: $5
---

# $1 — $2
EOF
}

# mk_graph — a fresh slices/ dir holding the canonical graph. Prints its path.
#   01 done  -> blocks 02, 03
#   04 ready -> blocks 03
#   frontier = 02 (blocker done) and 04 (no blockers); 03 waits on 04.
mk_graph() {
  d="$(mktemp -d "$tmp/graph.XXXXXX")/slices"
  mkdir -p "$d"
  slice 01 "prefactor" done ' []' '["02", "03"]' >"$d/01-prefactor.md"
  slice 02 "api" ready '["01"]' ' []' >"$d/02-api.md"
  slice 03 "ui" ready '["01", "04"]' ' []' >"$d/03-ui.md"
  slice 04 "cleanup" ready ' []' '["03"]' >"$d/04-cleanup.md"
  cat >"$d/INDEX.md" <<'EOF'
---
run: 20260101-fixture
spec: ../SPEC.md
slices: 4
---

# Slices — fixture
EOF
  echo "$d"
}

# patch <file> <sed-expr> — rewrite <file> through sed. NOT `sed -i`: BSD wants `-i ''` and GNU
# reads that empty string as a filename, so an in-place edit that works on macOS silently edits
# nothing on CI — which is exactly how the first version of this file passed locally and reported
# ten no-op defects as "check passed" on Linux.
#
# It also ASSERTS the file changed. A defect that fails to apply makes the graph healthy, so the
# case reports "check passed" — a false green that looks identical to a working test. Failing here
# instead means the next portability slip is caught as "defect did not apply", not as a pass.
patch() {
  sed "$2" "$1" >"$1.patched" || { echo "  ✗ patch: sed failed on $1 ($2)"; FAIL=$((FAIL + 1)); return 1; }
  if cmp -s "$1" "$1.patched"; then
    rm -f "$1.patched"
    echo "  ✗ patch: defect did not apply to $(basename "$1") ($2) — the case below is a false green"
    FAIL=$((FAIL + 1))
    return 1
  fi
  mv "$1.patched" "$1"
}

# defect <file> <sed-expr> — apply a one-line defect to the canonical graph. Prints the dir.
defect() {
  d="$(mk_graph)"
  patch "$d/$1" "$2"
  echo "$d"
}

# expect_check_pass / expect_check_fail <name> <dir>
expect_check_pass() {
  if "$SLICE_STATUS" --check "$2" >/dev/null 2>&1; then
    note_pass "$1"
  else
    note_fail "$1" "expected --check to pass"
  fi
}
expect_check_fail() {
  if "$SLICE_STATUS" --check "$2" >/dev/null 2>&1; then
    note_fail "$1" "expected --check to reject but it passed"
  else
    note_pass "$1"
  fi
}

# expect_frontier <name> <dir> <space-separated-ids>
expect_frontier() {
  got="$("$SLICE_STATUS" --frontier "$2" 2>/dev/null | tr '\n' ' ')"
  got="${got% }"
  if [ "$got" = "$3" ]; then
    note_pass "$1"
  else
    note_fail "$1" "frontier '$got' != expected '$3'"
  fi
}

# --- cases --------------------------------------------------------------------
echo "well-formed graph:"
good="$(mk_graph)"
expect_check_pass "check-clean" "$good"
expect_frontier "frontier-partial-done" "$good" "02 04"

echo "frontier semantics:"
# 04 done -> 03's blockers (01, 04) are all done, so 03 joins the frontier.
d="$(defect 04-cleanup.md 's/^status: ready/status: done/')"
expect_frontier "frontier-unlocks-03" "$d" "02 03"
# an explicitly `blocked` slice is never takeable, even with every blocker done.
d="$(defect 02-api.md 's/^status: ready/status: blocked/')"
expect_frontier "frontier-excludes-blocked" "$d" "04"
# a done slice is never in its own frontier.
d="$(defect 02-api.md 's/^status: ready/status: done/')"
expect_frontier "frontier-excludes-done" "$d" "04"

echo "malformed graph (expect rejection):"
expect_check_fail "one-sided-edge" "$(defect 01-prefactor.md 's/blocks: \["02", "03"\]/blocks: ["02"]/')"
expect_check_fail "dangling-target" "$(defect 03-ui.md 's/blocked_by: \["01", "04"\]/blocked_by: ["01", "09"]/')"
expect_check_fail "bad-status" "$(defect 02-api.md 's/^status: ready/status: wip/')"
expect_check_fail "id-filename-mismatch" "$(defect 02-api.md 's/^slice: "02"/slice: "07"/')"
expect_check_fail "missing-key" "$(defect 02-api.md '/^blocks:/d')"
expect_check_fail "index-count-mismatch" "$(defect INDEX.md 's/^slices: 4/slices: 3/')"

echo "duplicate id (two files claiming 02):"
d="$(mk_graph)"
sed 's/^slice: "04"/slice: "02"/' "$d/04-cleanup.md" >"$d/05-dupe.md"
patch "$d/INDEX.md" 's/^slices: 4/slices: 5/'
expect_check_fail "duplicate-id" "$d"

echo "no slice files:"
d="$(mktemp -d "$tmp/empty.XXXXXX")"
expect_check_fail "empty-dir" "$d"

echo "broken graph refuses to print a frontier:"
d="$(defect 01-prefactor.md 's/blocks: \["02", "03"\]/blocks: ["02"]/')"
if "$SLICE_STATUS" --frontier "$d" >/dev/null 2>&1; then
  note_fail "frontier-refuses-broken" "expected non-zero on an invalid graph"
else
  note_pass "frontier-refuses-broken"
fi

echo
echo "slice-status self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
