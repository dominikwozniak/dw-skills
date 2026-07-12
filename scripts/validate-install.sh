#!/usr/bin/env bash
# Isolated marketplace/install smoke for Codex and Claude Code.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/codex" "$TMP/claude"

command -v codex >/dev/null || { echo "::error::codex CLI is required"; exit 1; }
command -v claude >/dev/null || { echo "::error::claude CLI is required"; exit 1; }

echo "Codex install smoke"
CODEX_HOME="$TMP/codex" codex plugin marketplace add "$ROOT" --json >/dev/null
CODEX_HOME="$TMP/codex" codex plugin add dw-skills@dw-skills --json >/dev/null
CODEX_CACHE="$TMP/codex/plugins/cache/dw-skills/dw-skills/0.4.0"
if [ ! -d "$CODEX_CACHE" ]; then
  CODEX_CACHE=$(find "$TMP/codex/plugins/cache" -type d -path '*/dw-skills/*' | sort | tail -n1)
fi
[ -n "$CODEX_CACHE" ] && [ -d "$CODEX_CACHE" ] || { echo "::error::Codex cache missing"; exit 1; }
[ "$(find "$CODEX_CACHE/skills" -name SKILL.md | wc -l | tr -d ' ')" = 17 ]
[ "$(find "$CODEX_CACHE" -type l | wc -l | tr -d ' ')" = 0 ]
[ "$(find "$CODEX_CACHE/skills" -path '*/agents/openai.yaml' | wc -l | tr -d ' ')" = 5 ]
find "$CODEX_CACHE/scripts/runtime" -type f -name '*.sh' -exec test -x {} \;
if grep -R '/Users/dominik.wozniak' "$CODEX_CACHE/skills" "$CODEX_CACHE/scripts/runtime" "$CODEX_CACHE/.codex-plugin" >/dev/null 2>&1; then
  grep -R -l '/Users/dominik.wozniak' "$CODEX_CACHE/skills" "$CODEX_CACHE/scripts/runtime" "$CODEX_CACHE/.codex-plugin" | head -n5
  echo "::error::author-local absolute path found in Codex cache"; exit 1
fi
bash "$CODEX_CACHE/scripts/runtime/slugify.sh" branch-slug 'ABC-123/Test Branch' >/dev/null

echo "Claude install smoke"
CLAUDE_CONFIG_DIR="$TMP/claude" claude plugin marketplace add "$ROOT" --scope user >/dev/null
for plugin in dw-misc dw-planning dw-quality; do
  CLAUDE_CONFIG_DIR="$TMP/claude" claude plugin install "$plugin@dw-skills" --scope user >/dev/null
done
for plugin in dw-misc dw-planning dw-quality; do
  find "$TMP/claude/plugins/cache/dw-skills/$plugin" -name plugin.json -print -quit | grep -q .
done
if find "$TMP/claude/plugins/cache" -type l | grep -q .; then
  echo "::error::Claude cache contains symlinks"; exit 1
fi

echo "OK  isolated Codex and Claude installs"
