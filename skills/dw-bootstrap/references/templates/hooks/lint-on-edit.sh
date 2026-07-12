#!/usr/bin/env bash
# PostToolUse hook — runs the project's lint command on the edited file.
# Supports Claude file_path events and Codex apply_patch payloads.
# Lint command resolved in order:
#   1. CLAUDE.local.md "Lint command:" value (if present)
#   2. package.json scripts.lint (with --fix if eslint/biome detected)
#   3. pnpm exec eslint --fix / npx eslint --fix
# Exits 0 on success, 2 + stderr on lint failure so Claude self-corrects.

set -uo pipefail

command -v jq >/dev/null || exit 0

input=$(cat)
tool_name=$(jq -r '.tool_name // empty' <<<"$input")
file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input")

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

if [[ "$tool_name" == "apply_patch" ]]; then
  file_path=$(jq -r '.tool_input.command // empty' <<<"$input" | sed -nE 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' | head -n1)
fi

[[ -z "$file_path" ]] && exit 0
[[ -f "$file_path" ]] || exit 0
[[ "$file_path" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]] || exit 0

repo_root="$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$repo_root" || exit 0

resolve_lint_cmd() {
  local instructions from_md
  for instructions in DW.local.md CLAUDE.local.md AGENTS.md CLAUDE.md; do
    [[ -f "$instructions" ]] || continue
    from_md=$(grep -E "^\s*[-*]?\s*\*\*?Lint command\*\*?:" "$instructions" | sed -E 's/.*Lint command\*?\*?:\s*`?([^`]+)`?.*/\1/' | head -n1)
    if [[ -n "$from_md" && "$from_md" != "{{LINT_COMMAND}}" ]]; then
      echo "$from_md"
      return
    fi
  done
  if command -v pnpm >/dev/null && [[ -f "package.json" ]] && jq -e '.devDependencies.eslint // .dependencies.eslint' package.json >/dev/null 2>&1; then
    echo "pnpm exec eslint --fix --max-warnings 0"
    return
  fi
  if command -v npx >/dev/null && [[ -f "package.json" ]] && jq -e '.devDependencies.eslint // .dependencies.eslint' package.json >/dev/null 2>&1; then
    echo "npx eslint --fix --max-warnings 0"
    return
  fi
  echo ""
}

cmd=$(resolve_lint_cmd)
[[ -z "$cmd" ]] && exit 0

if ! output=$(eval "$cmd \"$file_path\"" 2>&1); then
  {
    echo "Lint failed for $file_path ($cmd):"
    echo "$output"
  } >&2
  exit 2
fi

exit 0
