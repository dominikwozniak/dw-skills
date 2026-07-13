#!/usr/bin/env bash
# Isolated marketplace/install smoke for Codex and Claude Code.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
VERSION=$(jq -r '.version' "$ROOT/package.json")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/codex" "$TMP/claude"

command -v codex >/dev/null || { echo "::error::codex CLI is required"; exit 1; }
command -v claude >/dev/null || { echo "::error::claude CLI is required"; exit 1; }

echo "Codex install smoke"
CODEX_HOME="$TMP/codex" codex plugin marketplace add "$ROOT" --json >/dev/null
CODEX_HOME="$TMP/codex" codex plugin add dw-skills@dw-skills --json >/dev/null
CODEX_LIST=$(CODEX_HOME="$TMP/codex" codex plugin list --json)
jq -e --arg version "$VERSION" '[.installed[] | select(.pluginId == "dw-skills@dw-skills" and .installed == true and .enabled == true and .version == $version)] | length == 1' <<<"$CODEX_LIST" >/dev/null || {
  echo "::error::Codex plugin list does not contain one enabled dw-skills@$VERSION entry"; exit 1;
}
CODEX_CACHE="$TMP/codex/plugins/cache/dw-skills/dw-skills/$VERSION"
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
CLAUDE_LIST=$(CLAUDE_CONFIG_DIR="$TMP/claude" claude plugin list --json)
for plugin in dw-misc dw-planning dw-quality; do
  id="$plugin@dw-skills"
  jq -e --arg id "$id" --arg version "$VERSION" '[.[] | select(.id == $id and .enabled == true and .version == $version and (.installPath | length > 0))] | length == 1' <<<"$CLAUDE_LIST" >/dev/null || {
    echo "::error::Claude plugin list missing enabled $id@$VERSION"; exit 1;
  }
  install_path=$(jq -r --arg id "$id" '.[] | select(.id == $id) | .installPath' <<<"$CLAUDE_LIST")
  [ -d "$install_path" ] || { echo "::error::Claude installPath missing for $id"; exit 1; }
  case "$plugin" in
    dw-misc) expected_skills=5; expected_runtime=0 ;;
    dw-planning) expected_skills=5; expected_runtime=5 ;;
    dw-quality) expected_skills=7; expected_runtime=1 ;;
  esac
  [ "$(find "$install_path/skills" -name SKILL.md | wc -l | tr -d ' ')" = "$expected_skills" ] || {
    echo "::error::$id skill payload incomplete"; exit 1;
  }
  runtime_count=0
  [ ! -d "$install_path/scripts/runtime" ] || runtime_count=$(find "$install_path/scripts/runtime" -type f -name '*.sh' | wc -l | tr -d ' ')
  [ "$runtime_count" = "$expected_runtime" ] || { echo "::error::$id runtime payload incomplete"; exit 1; }
  if [ "$expected_runtime" -gt 0 ]; then
    find "$install_path/scripts/runtime" -type f -name '*.sh' -exec test -x {} \;
  fi
done
if find "$TMP/claude/plugins/cache" -type l | grep -q .; then
  echo "::error::Claude cache contains symlinks"; exit 1
fi

echo "OK  isolated Codex and Claude installs"
