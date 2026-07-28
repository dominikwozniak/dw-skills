#!/usr/bin/env bash
# slice-status.sh — structural check + frontier derivation for a run's slices/ graph.
#
# What PLAN.md is to dw-plan, slices/ is to dw-split: the artifact the next session reads
# to know what to do. A plan's resume point is the first not-done row — one rule, computed
# by plan-status.sh. A graph's equivalent is its FRONTIER (every slice takeable right now),
# and it is just as much a pure function of the files. So it lives here, in one script, and
# both dw-split and dw-resume call it rather than each re-deriving it in-context.
#
# The graph also has invariants a list doesn't: an edge must be recorded on both ends, and
# every number it names must exist. A one-sided edge silently hides a dependency, which is
# exactly the failure the graph topology was adopted to avoid — so it fails here, loudly.
#
# Frontier rule:
#   takeable = status not in {done, blocked} AND every blocked_by slice is done
#   `blocked` is an explicit "not takeable" marker (e.g. waiting on another team) and is
#   never in the frontier even when its recorded blockers are all done.
#
# Checks (--check):
#   slice files  <dir>/NN-*.md; frontmatter fenced; keys slice/run/title/status/blocked_by/
#                blocks present; status in {ready, doing, done, blocked}; `slice:` is NN,
#                matches the filename prefix, unique, strictly increasing.
#   edges        every blocked_by / blocks target exists, and every edge is recorded
#                reciprocally on the other end.
#   INDEX.md     present; frontmatter `slices:` equals the number of slice files.
#
# Usage:
#   slice-status.sh --check <slices-dir>      report structure; exit non-zero on any failure
#   slice-status.sh --frontier <slices-dir>   print the takeable slice ids, one per line
#
# Writes NOTHING, ever. Exit 0 iff all checks pass. bash 3.2 / macOS safe.
set -uo pipefail
export LC_ALL=C

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

mode=""
case "${1:-}" in
  --check | --frontier) mode="$1"; shift ;;
  *)
    echo "usage: slice-status.sh --check|--frontier <slices-dir>" >&2
    exit 1
    ;;
esac

dir="${1:-}"
if [ -z "$dir" ]; then
  echo "usage: slice-status.sh --check|--frontier <slices-dir>" >&2
  exit 1
fi
dir="${dir%/}"
if [ ! -d "$dir" ]; then
  echo "slice-status.sh: no such directory: $dir" >&2
  exit 1
fi

# --- frontmatter helpers (first --- ... --- block) ----------------------------

# fm_ok <file> — succeed if the file opens with a --- fence and has a closing ---.
# NB: awk runs END even after a body `exit`, so the verdict is computed in END from flags.
fm_ok() {
  awk '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { bad=1; exit }
    /^---[[:space:]]*$/ { f++ }
    END { exit (bad || f < 2) ? 1 : 0 }
  ' "$1"
}

# fm_value <file> <key> — print the frontmatter value of <key>, comment and quotes stripped.
fm_value() {
  awk -v key="$2" '
    /^---[[:space:]]*$/ { f++; if (f==2) exit; next }
    f==1 && $0 ~ ("^" key ":") {
      v=$0; sub("^" key ":[[:space:]]*","",v); sub(/[[:space:]]*#.*$/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
      gsub(/^["'"'"']|["'"'"']$/,"",v)
      print v; exit
    }
  ' "$1"
}

# fm_has_key <file> <key> — succeed if the frontmatter declares <key>:.
fm_has_key() {
  awk -v key="$2" '
    /^---[[:space:]]*$/ { f++; if (f==2) exit; next }
    f==1 && $0 ~ ("^" key ":") { found=1; exit }
    END { exit found ? 0 : 1 }
  ' "$1"
}

# fm_list <file> <key> — a `["01", "02"]` flow list as space-separated ids ('' when empty).
fm_list() {
  raw="$(fm_value "$1" "$2")"
  raw="$(printf '%s' "$raw" | tr -d '[]"'"'" | tr ',' ' ')"
  # shellcheck disable=SC2086 # deliberate word-split to normalise whitespace
  echo $raw
}

# --- collect the graph -------------------------------------------------------
# One record per slice: "<id> <status> <blocked_by...> | <blocks...>" kept in two flat
# strings (bash 3.2 has no associative arrays), plus a space-padded id index for lookups.

IDS=""              # " 01 02 03 "
REC_STATUS=""       # "01=ready 02=done ..."
REC_BLOCKED_BY=""   # "01=- 03=01,02 ..."  ('-' = none)
REC_BLOCKS=""       # same shape

# lookup <table> <id> — print the value recorded for <id> ('' if absent).
lookup() {
  for pair in $1; do
    case "$pair" in "$2="*) printf '%s' "${pair#*=}"; return 0 ;; esac
  done
  return 1
}

# in_csv <needle> <comma-list> — succeed if present.
in_csv() {
  [ "$2" = "-" ] && return 1
  for w in $(printf '%s' "$2" | tr ',' ' '); do [ "$w" = "$1" ] && return 0; done
  return 1
}

prev_id=""
count=0
for f in "$dir"/[0-9][0-9]-*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  count=$((count + 1))

  if ! fm_ok "$f"; then
    fail "$base: missing or unterminated --- frontmatter"
    continue
  fi
  for k in slice run title status blocked_by blocks; do
    fm_has_key "$f" "$k" || fail "$base: missing frontmatter key '$k'"
  done

  id="$(fm_value "$f" slice)"
  case "$id" in
    [0-9][0-9]) ;;
    *) fail "$base: frontmatter slice: '$id' is not a two-digit id (NN)"; continue ;;
  esac
  [ "$id" = "${base%%-*}" ] || fail "$base: frontmatter slice: '$id' != filename prefix '${base%%-*}'"
  case "$IDS" in
    *" $id "*) fail "$base: duplicate slice id '$id'" ;;
    *) IDS="$IDS $id " ;;
  esac
  if [ -n "$prev_id" ] && [ "$id" -le "$prev_id" ] 2>/dev/null; then
    fail "$base: slice ids must strictly increase ('$id' after '$prev_id')"
  fi
  prev_id="$id"

  st="$(fm_value "$f" status)"
  case "$st" in
    ready | doing | done | blocked) ;;
    *) fail "$base: status '$st' not in {ready, doing, done, blocked}" ;;
  esac

  bb="$(fm_list "$f" blocked_by | tr ' ' ',')"
  bl="$(fm_list "$f" blocks | tr ' ' ',')"
  REC_STATUS="$REC_STATUS $id=${st:--}"
  REC_BLOCKED_BY="$REC_BLOCKED_BY $id=${bb:--}"
  REC_BLOCKS="$REC_BLOCKS $id=${bl:--}"
done

if [ "$count" -eq 0 ]; then
  fail "$dir: no NN-*.md slice files found"
  exit 1
fi

# --- edges: resolvable and reciprocal ----------------------------------------

for id in $IDS; do
  for b in $(printf '%s' "$(lookup "$REC_BLOCKED_BY" "$id")" | tr ',' ' '); do
    [ "$b" = "-" ] && continue
    case "$IDS" in
      *" $b "*)
        in_csv "$id" "$(lookup "$REC_BLOCKS" "$b")" \
          || fail "slice $id declares blocked_by $b, but $b does not list $id in blocks (one-sided edge)"
        ;;
      *) fail "slice $id declares blocked_by $b, but no slice $b exists" ;;
    esac
  done
  for c in $(printf '%s' "$(lookup "$REC_BLOCKS" "$id")" | tr ',' ' '); do
    [ "$c" = "-" ] && continue
    case "$IDS" in
      *" $c "*)
        in_csv "$id" "$(lookup "$REC_BLOCKED_BY" "$c")" \
          || fail "slice $id declares blocks $c, but $c does not list $id in blocked_by (one-sided edge)"
        ;;
      *) fail "slice $id declares blocks $c, but no slice $c exists" ;;
    esac
  done
done

# --- INDEX.md ----------------------------------------------------------------

index="$dir/INDEX.md"
if [ ! -f "$index" ]; then
  fail "$dir: INDEX.md not found"
elif ! fm_ok "$index"; then
  fail "INDEX.md: missing or unterminated --- frontmatter"
else
  declared="$(fm_value "$index" slices)"
  if [ -z "$declared" ]; then
    fail "INDEX.md: missing frontmatter key 'slices'"
  elif [ "$declared" != "$count" ]; then
    fail "INDEX.md: declares slices: $declared but $count slice files exist"
  fi
fi

# --- output ------------------------------------------------------------------

if [ "$mode" = "--frontier" ]; then
  # A broken graph makes the frontier meaningless — refuse rather than print a wrong one.
  [ "$FAILED" -eq 0 ] || { echo "slice-status.sh: graph is invalid; run --check" >&2; exit 1; }
  for id in $IDS; do
    st="$(lookup "$REC_STATUS" "$id")"
    case "$st" in done | blocked) continue ;; esac
    takeable=1
    for b in $(printf '%s' "$(lookup "$REC_BLOCKED_BY" "$id")" | tr ',' ' '); do
      [ "$b" = "-" ] && continue
      [ "$(lookup "$REC_STATUS" "$b")" = "done" ] || takeable=0
    done
    [ "$takeable" -eq 1 ] && echo "$id"
  done
  exit 0
fi

if [ "$FAILED" -eq 0 ]; then
  n_done=0
  for id in $IDS; do
    [ "$(lookup "$REC_STATUS" "$id")" = "done" ] && n_done=$((n_done + 1))
  done
  echo "slices: $count ($n_done done) (ok)"
fi
exit $FAILED
