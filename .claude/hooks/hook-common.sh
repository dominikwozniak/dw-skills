#!/usr/bin/env bash
# Shared helpers for dw-bootstrap hooks. This file is sourced, not wired as a hook.
# Automatic commands may come only from ignored, user-owned local instruction files.

dw_hook_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

dw_hook_normalize_path() {
  local repo_root="$1" candidate="$2" directory basename absolute
  [ -n "$candidate" ] || return 1

  if [[ "$candidate" = /* ]]; then
    absolute="$candidate"
  else
    absolute="$repo_root/$candidate"
  fi

  [ -f "$absolute" ] || return 1
  repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || return 1
  if command -v realpath >/dev/null 2>&1; then
    absolute="$(realpath "$absolute" 2>/dev/null)" || return 1
  else
    [ ! -L "$absolute" ] || return 1
    directory="$(cd "$(dirname "$absolute")" 2>/dev/null && pwd -P)" || return 1
    basename="$(basename "$absolute")"
    absolute="$directory/$basename"
  fi

  case "$absolute" in
    "$repo_root"/*) printf '%s\n' "$absolute" ;;
    *) return 1 ;;
  esac
}

# Print every unique, existing file referenced by a supported host payload.
# Deleted files and paths outside the active repository are intentionally omitted.
dw_hook_changed_paths() {
  local input="$1" repo_root="$2" tool_name candidate normalized seen
  tool_name="$(jq -r '.tool_name // empty' <<<"$input")"
  seen=""

  if [ "$tool_name" = "apply_patch" ]; then
    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue
      normalized="$(dw_hook_normalize_path "$repo_root" "$candidate")" || continue
      case "$seen" in
        *"|$normalized|"*) continue ;;
      esac
      seen="$seen|$normalized|"
      printf '%s\n' "$normalized"
    done < <(jq -r '.tool_input.command // empty' <<<"$input" | sed -nE -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' -e 's/^\*\*\* Move to: (.*)$/\1/p')
    return
  fi

  candidate="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty' <<<"$input")"
  normalized="$(dw_hook_normalize_path "$repo_root" "$candidate")" || return 0
  printf '%s\n' "$normalized"
}

# Read a command only from ignored, local overrides. Tracked AGENTS.md and CLAUDE.md
# remain agent instructions and are never an automatic execution source.
dw_hook_local_command() {
  local label="$1" placeholder="$2" instructions from_md
  for instructions in DW.local.md CLAUDE.local.md; do
    [ -f "$instructions" ] || continue
    # The command is the first backtick-delimited span when one exists
    # ('`pnpm lint` — note' → 'pnpm lint'), so trailing annotations survive;
    # a value without a backtick pair is taken whole, trimmed.
    from_md="$(grep -E "^[[:space:]]*[-*]?[[:space:]]*\*\*?${label}\*\*?:" "$instructions" | sed -E 's/^[^:]+:[[:space:]]*//; s/^[^`]*`([^`]+)`.*$/\1/; s/^`//; s/`[[:space:]]*$//; s/[[:space:]]+$//' | head -n1)"
    if [ -n "$from_md" ] && [ "$from_md" != "$placeholder" ] && [ "$from_md" != "_(n/a)_" ]; then
      printf '%s\n' "$from_md"
      return
    fi
  done
}

# Populate global DW_HOOK_ARGV from a whitespace-delimited command. Shell syntax is
# rejected deliberately: local hook commands are argv, not shell programs.
dw_hook_parse_argv() {
  local command_text="$1"
  DW_HOOK_ARGV=()
  [ -n "$command_text" ] || return 1

  if [[ "$command_text" == *$'\n'* || "$command_text" == *$'\r'* || "$command_text" == *\"* || "$command_text" == *\'* ]] ||
    printf '%s' "$command_text" | grep -qE '[;&|<>`$()]'; then
    echo "Invalid local hook command: use a whitespace-delimited argv list without shell metacharacters, substitutions, variables, pipes, redirects, or separators: $command_text" >&2
    return 2
  fi

  read -r -a DW_HOOK_ARGV <<<"$command_text"
  [ "${#DW_HOOK_ARGV[@]}" -gt 0 ]
}
