#!/usr/bin/env bash
# PostToolUse hook — lints every existing Ruby file from a Claude edit or Codex patch.
# Trusted local commands come only from DW.local.md, then legacy CLAUDE.local.md.
# Otherwise the hook builds a fixed argv from Gemfile. No shell text is evaluated.

set -uo pipefail

command -v jq >/dev/null || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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
  [[ "$file_path" =~ \.rb$ ]] || continue
  files+=("$file_path")
done < <(dw_hook_changed_paths "$input" "$repo_root")
[ "${#files[@]}" -gt 0 ] || exit 0

local_command="$(dw_hook_local_command "Lint command" "{{LINT_COMMAND}}")"
if [ -n "$local_command" ]; then
  dw_hook_parse_argv "$local_command" || exit $?
  command_argv=("${DW_HOOK_ARGV[@]}")
elif [ -f Gemfile ] && command -v bundle >/dev/null && grep -qE "^[[:space:]]*gem[[:space:]]+[\"']standard[\"']" Gemfile; then
  command_argv=(bundle exec standardrb --fix)
elif [ -f Gemfile ] && command -v bundle >/dev/null && grep -qE "^[[:space:]]*gem[[:space:]]+[\"']rubocop" Gemfile; then
  command_argv=(bundle exec rubocop -A)
else
  exit 0
fi

if ! output="$("${command_argv[@]}" "${files[@]}" 2>&1)"; then
  {
    echo "Ruby lint failed for ${files[*]} (${command_argv[*]}):"
    echo "$output"
  } >&2
  exit 2
fi
