#!/usr/bin/env bash
# find-active-run.sh — locate the active .ai/runs/<id>/ for the current branch.
#
# dw-resume / dw-build / dw-sync all need the same answer: which run belongs to
# this branch, and (for build/resume) which is the first not-done step. Leaving
# that to prose meant each skill re-derived it a little differently. One script,
# one rule: match SPEC frontmatter `branch:` to the current git branch; the
# resume point is the first PLAN row whose Status != done (same rule everywhere).
#
# Usage:
#   find-active-run.sh           print the matching run directory (absolute path)
#   find-active-run.sh --step    also print the first PLAN row whose Status != done
#
# Exit 1 if no run matches the current branch.
set -euo pipefail

want_step=0
[ "${1:-}" = "--step" ] && want_step=1

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
runs_dir="$root/.ai/runs"

[ -d "$runs_dir" ] || { echo "find-active-run.sh: no .ai/runs directory under $root" >&2; exit 1; }

# Print the frontmatter `branch:` value of a SPEC.md (empty if absent).
spec_branch() {
  awk '
    /^---[[:space:]]*$/ { f++; if (f==2) exit; next }
    f==1 && /^branch:/ {
      v=$0; sub(/^branch:[[:space:]]*/,"",v); sub(/[[:space:]]*#.*$/,"",v); gsub(/[[:space:]]/,"",v)
      print v; exit
    }
  ' "$1"
}

matches=()
for spec in "$runs_dir"/*/SPEC.md; do
  [ -f "$spec" ] || continue
  if [ "$(spec_branch "$spec")" = "$branch" ]; then
    matches+=("$(dirname "$spec")")
  fi
done

if [ "${#matches[@]}" -eq 0 ]; then
  echo "find-active-run.sh: no run matches branch '$branch'" >&2
  exit 1
fi

# Most recent wins (run-id is date-prefixed, so a lexical sort orders by age).
IFS=$'\n' sorted=($(printf '%s\n' "${matches[@]}" | sort)); unset IFS
last=$(( ${#sorted[@]} - 1 ))
run_dir="${sorted[$last]}"
if [ "${#sorted[@]}" -gt 1 ]; then
  echo "find-active-run.sh: ${#sorted[@]} runs match '$branch'; using newest: $(basename "$run_dir")" >&2
fi

printf '%s\n' "$run_dir"
[ "$want_step" -eq 1 ] || exit 0

plan="$run_dir/PLAN.md"
if [ ! -f "$plan" ]; then
  echo "step: none (no PLAN.md yet — run dw-plan)"
  exit 0
fi

# First table row whose Status column != done — the resume point.
awk '
  BEGIN { hdr=0; scol=0; stepcol=0; titlecol=0; found=0 }
  hdr==0 && /\|/ && /[Ss]tatus/ && /[Cc]ommit/ {
    hdr=1; nf=split($0, c, "|")
    for (i=1;i<=nf;i++) {
      x=c[i]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",x); lx=tolower(x)
      if (lx=="status") scol=i
      if (lx=="step")   stepcol=i
      if (lx=="title")  titlecol=i
    }
    next
  }
  hdr==1 {
    if ($0 !~ /\|/) exit
    if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]+\|[[:space:]]*$/) next
    split($0, c, "|")
    s=c[scol]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); gsub(/`/,"",s); s=tolower(s)
    if (s=="") next
    if (s!="done") {
      st=c[stepcol];  gsub(/^[[:space:]]+|[[:space:]]+$/,"",st)
      ti=c[titlecol]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",ti)
      printf "step: %s\nstatus: %s\ntitle: %s\n", st, s, ti
      found=1; exit
    }
  }
  END { if (!found) print "step: none (all steps done)" }
' "$plan"
