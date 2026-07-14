#!/usr/bin/env bash
# Validate Claude manifests, shared versioning, and the shipped runtime layout.
set -uo pipefail

FOUND=0
FAILED=0

while IFS= read -r file; do
  FOUND=1
  echo "Validating $file..."
  if ! claude plugin validate "$file"; then
    FAILED=1
  fi
done < <(find . -type f \( -path './.claude-plugin/marketplace.json' -o -path './plugins/*/.claude-plugin/plugin.json' \) | sort)

if [ "$FOUND" -eq 0 ]; then
  echo "No manifest files found."
  exit 0
fi

echo
echo "Checking version sync between marketplace.json and plugin.json..."
canonical_version=$(jq -r '.version' package.json)
for pair in \
  ".claude-plugin/marketplace.json:$(jq -r '.metadata.version' .claude-plugin/marketplace.json)" \
  ".codex-plugin/plugin.json:$(jq -r '.version' .codex-plugin/plugin.json)"; do
  file=${pair%%:*}; version=${pair#*:}
  if [ "$version" != "$canonical_version" ]; then
    echo "::error::$file=$version vs package.json=$canonical_version"
    FAILED=1
  fi
done
while IFS=$'\t' read -r name source mp_v; do
  pj_v=$(jq -r '.version' "${source#./}/.claude-plugin/plugin.json")
  if [ "$mp_v" = "$pj_v" ]; then
    echo "OK  $name=$mp_v"
  else
    echo "::error::$name: marketplace.json=$mp_v vs plugin.json=$pj_v"
    FAILED=1
  fi
done < <(jq -r '.plugins[] | [.name, .source, .version] | @tsv' .claude-plugin/marketplace.json)

echo
echo "Checking shipped scripts (canon in scripts/runtime/, symlinked into plugins)..."
# Shipped scripts live once under scripts/runtime/ and are exposed to each plugin via a
# git-tracked symlink plugins/<p>/scripts/runtime/<s>.sh -> ../../../../scripts/runtime/<s>.sh. `claude
# plugin install` dereferences the symlink into a real file in the plugin cache, so the runtime
# installed skills resolve helpers through their relative scripts/runtime layout. We assert each canon and link.
# executable, and (2) each plugin entry is a symlink that resolves to it — never a real file
# (a real file would reintroduce the duplication this layout removes).
RUNTIME_SCRIPTS="slugify.sh new-run.sh find-active-run.sh plan-status.sh validate-ai-artifacts.sh"
for s in $RUNTIME_SCRIPTS; do
  c="scripts/runtime/$s"
  if [ ! -f "$c" ]; then
    echo "::error::missing canonical script: $c"
    FAILED=1
  elif [ ! -x "$c" ]; then
    echo "::error::$c is not executable (chmod +x)"
    FAILED=1
  else
    echo "OK  $c (canon, executable)"
  fi
done

# check_symlink <plugin-script-path> — must be a symlink that resolves (and runs) via the canon.
# Runs in the current shell (no subshell), so FAILED assignments here persist.
check_symlink() {
  link="$1"
  if [ ! -L "$link" ]; then
    echo "::error::$link must be a symlink into scripts/runtime/ (real file or missing)"
    FAILED=1
  elif [ ! -e "$link" ]; then
    echo "::error::$link is a dangling symlink (target '$(readlink "$link")' missing)"
    FAILED=1
  elif [ ! -x "$link" ]; then
    echo "::error::$link resolves to a non-executable target"
    FAILED=1
  else
    echo "OK  $link -> $(readlink "$link")"
  fi
}

echo
echo "Checking plugin script symlinks resolve to the canon..."
for s in $RUNTIME_SCRIPTS; do
  check_symlink "plugins/dw-planning/scripts/runtime/$s"
done
check_symlink "plugins/dw-quality/scripts/runtime/slugify.sh"

exit $FAILED
