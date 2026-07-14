#!/bin/bash
# PreToolUse hook — blocks reading/editing/writing .env files (secrets).
# Wire with matcher "Read|Edit|Write|MultiEdit|NotebookEdit|Grep|Bash|apply_patch":
# file tools are checked via tool_input.file_path/.notebook_path/.path,
# Bash via tokens of tool_input.command (cat .env, source .env, cp x .env).
# Allowed basenames: .env.example / .env.sample / .env.template (secret-free).
# Exit 2 + stderr message causes the host to see the block and self-correct.
# Guardrail against accidental secret exposure — NOT a security boundary
# (quoted paths in Bash slip through; permissions.deny is the backstop).

set -uo pipefail

command -v jq >/dev/null || exit 0

INPUT=$(cat)

ALLOWED_BASENAMES=(".env.example" ".env.sample" ".env.template")

# is_env_file <path-or-token> — 0 if basename is .env / .env.* / .envrc
# and not on the allowlist.
is_env_file() {
  local base="${1##*/}"
  [[ "$base" =~ ^\.env(\..+)?$ || "$base" == ".envrc" ]] || return 1
  local allowed
  for allowed in "${ALLOWED_BASENAMES[@]}"; do
    [[ "$base" == "$allowed" ]] && return 1
  done
  return 0
}

block() {
  echo "BLOCKED: $1 touches '$2' — .env files hold secrets and must not be read or modified by the agent (.env.example / .env.sample / .env.template are fine). Refused by dw-bootstrap guardrail. If this is genuinely needed (e.g. 'cp .env.example .env'), ask the user to run it manually." >&2
  exit 2
}

TOOL_NAME=$(jq -r '.tool_name // "tool"' <<<"$INPUT")

# File tools: a single path field.
FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty' <<<"$INPUT")
if [[ -n "$FILE_PATH" ]]; then
  is_env_file "$FILE_PATH" && block "$TOOL_NAME" "$FILE_PATH"
fi

# Bash: strip quoted spans (so prose like `git commit -m "docs: .env"` passes),
# split on shell separators, check each token's basename. Newlines are folded
# to spaces first — sed strips quotes per line, so a multi-line quoted string
# (heredoc-style commit body) would otherwise leak its inner lines as tokens.
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
if [[ -n "$COMMAND" ]]; then
  if [[ "$TOOL_NAME" == "apply_patch" ]]; then
    # Patch headers name every touched path (incl. "Move to:" rename targets,
    # possibly quoted); the body is file content and is never token-scanned —
    # a patch that merely mentions .env in a doc or code line must pass.
    while IFS= read -r patch_path; do
      # A header path is the exact file — normalise it: trim surrounding
      # whitespace (incl. a trailing CR from CRLF patches), strip one layer of
      # quotes, trim again, so a padded or quoted `.env` can't slip the scan.
      patch_path="${patch_path#"${patch_path%%[![:space:]]*}"}"
      patch_path="${patch_path%"${patch_path##*[![:space:]]}"}"
      patch_path="${patch_path#\"}"; patch_path="${patch_path%\"}"
      patch_path="${patch_path#\'}"; patch_path="${patch_path%\'}"
      patch_path="${patch_path#"${patch_path%%[![:space:]]*}"}"
      patch_path="${patch_path%"${patch_path##*[![:space:]]}"}"
      [[ -z "$patch_path" ]] && continue
      is_env_file "$patch_path" && block "apply_patch" "$patch_path"
    done < <(printf '%s\n' "$COMMAND" | sed -nE -e 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p' -e 's/^\*\*\* Move to: (.*)$/\1/p')
    exit 0
  fi
  STRIPPED=$(printf '%s\n' "$COMMAND" | tr '\n' ' ' | sed -E 's/"[^"]*"//g' | sed -E "s/'[^']*'//g")
  while IFS= read -r token; do
    [[ -z "$token" ]] && continue
    is_env_file "$token" && block "Bash command" "$token"
  done < <(printf '%s\n' "$STRIPPED" | tr -s "[:space:];|&()<>=\`\"'" '\n')
fi

exit 0
