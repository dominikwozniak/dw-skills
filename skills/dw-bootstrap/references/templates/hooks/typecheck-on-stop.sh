#!/usr/bin/env bash
# Stop hook — runs typecheck when TS/TSX files changed in the working tree.
# Trusted local commands come only from DW.local.md, then legacy CLAUDE.local.md.
# Otherwise the hook builds a fixed argv from detected manifests. No shell text is evaluated.

set -uo pipefail

[[ -n "${DW_SKIP_TYPECHECK:-}${CLAUDE_SKIP_TYPECHECK:-}" ]] && exit 0
command -v jq >/dev/null || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ ! -r "$SCRIPT_DIR/hook-common.sh" ]; then
  echo "dw hook: hook-common.sh missing beside $(basename "${BASH_SOURCE[0]}") — guardrail cannot run" >&2
  exit 2
fi
# shellcheck source=hook-common.sh
source "$SCRIPT_DIR/hook-common.sh"

repo_root="$(dw_hook_repo_root)" || exit 0
cd "$repo_root" || exit 0

changed="$({
  git diff --name-only --diff-filter=ACMR
  git diff --name-only --cached --diff-filter=ACMR
  git ls-files --others --exclude-standard
} | grep -E '\.(ts|tsx)$' || true)"
[ -n "$changed" ] || exit 0

local_command="$(dw_hook_local_command "Typecheck command" "{{TYPECHECK_COMMAND}}")"
if [ -n "$local_command" ]; then
  dw_hook_parse_argv "$local_command" || exit $?
  command_argv=("${DW_HOOK_ARGV[@]}")
elif [ -f package.json ] && jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
  if command -v pnpm >/dev/null && [ -f pnpm-lock.yaml ]; then
    command_argv=(pnpm run typecheck)
  else
    command_argv=(npm run typecheck)
  fi
elif command -v pnpm >/dev/null && [ -f tsconfig.json ]; then
  command_argv=(pnpm exec tsc --noEmit)
elif command -v npx >/dev/null && [ -f tsconfig.json ]; then
  command_argv=(npx tsc --noEmit)
else
  exit 0
fi

if ! output="$("${command_argv[@]}" 2>&1)"; then
  {
    echo "Typecheck failed (${command_argv[*]}):"
    echo "$output"
  } >&2
  exit 2
fi
