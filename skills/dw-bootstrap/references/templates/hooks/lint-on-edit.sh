#!/usr/bin/env bash
# PostToolUse hook — lints every existing JS/TS file from a Claude edit or Codex patch.
# Trusted local commands come only from DW.local.md, then legacy CLAUDE.local.md.
# Otherwise the hook builds a fixed argv from detected manifests. No shell text is evaluated.

set -uo pipefail

command -v jq >/dev/null || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ ! -r "$SCRIPT_DIR/hook-common.sh" ]; then
  echo "dw hook: hook-common.sh missing beside $(basename "${BASH_SOURCE[0]}") — guardrail cannot run" >&2
  exit 2
fi
# shellcheck source=hook-common.sh
source "$SCRIPT_DIR/hook-common.sh"

input="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<<"$input")"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

repo_root="$(dw_hook_repo_root)" || exit 0
cd "$repo_root" || exit 0

files=()
while IFS= read -r file_path; do
  [[ "$file_path" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]] || continue
  files+=("$file_path")
done < <(dw_hook_changed_paths "$input" "$repo_root")
[ "${#files[@]}" -gt 0 ] || exit 0

local_command="$(dw_hook_local_command "Lint command" "{{LINT_COMMAND}}")"
if [ -n "$local_command" ]; then
  dw_hook_parse_argv "$local_command" || exit $?
  command_argv=("${DW_HOOK_ARGV[@]}")
elif command -v pnpm >/dev/null && [ -f package.json ] && jq -e '.devDependencies.eslint // .dependencies.eslint' package.json >/dev/null 2>&1; then
  command_argv=(pnpm exec eslint --fix --max-warnings 0)
elif command -v npx >/dev/null && [ -f package.json ] && jq -e '.devDependencies.eslint // .dependencies.eslint' package.json >/dev/null 2>&1; then
  command_argv=(npx eslint --fix --max-warnings 0)
else
  exit 0
fi

if ! output="$("${command_argv[@]}" "${files[@]}" 2>&1)"; then
  {
    echo "Lint failed for ${files[*]} (${command_argv[*]}):"
    echo "$output"
  } >&2
  exit 2
fi
