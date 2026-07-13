#!/usr/bin/env bash
# Fixture-driven self-test for dw-doctor plugin diagnostics. bash 3.2 safe.
set -uo pipefail
export LC_ALL=C

command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DOCTOR="$ROOT/skills/dw-doctor/scripts/doctor.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
BIN="$TMP/bin"
export CODEX_HOME="$TMP/codex-home"
export HOME="$TMP/home"
mkdir -p "$REPO/.ai" "$REPO/.claude" "$REPO/.codex" "$BIN" "$HOME"
git -C "$REPO" init -q
touch "$REPO/AGENTS.md" "$REPO/DW.local.md"

cat >"$BIN/codex" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then echo "codex-cli ${CODEX_CLI_VERSION:-0.142.0}"; exit 0; fi
if [ "${1:-} ${2:-} ${3:-}" = "plugin list --json" ]; then cat "$CODEX_FIXTURE"; exit 0; fi
exit 1
SH
cat >"$BIN/claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then echo "2.1.0"; exit 0; fi
if [ "${1:-} ${2:-} ${3:-}" = "plugin list --json" ]; then cat "$CLAUDE_FIXTURE"; exit 0; fi
exit 1
SH
chmod +x "$BIN/codex" "$BIN/claude"
export PATH="$BIN:$PATH"

make_codex_cache() {
  local version="$1" cache i
  cache="$CODEX_HOME/plugins/cache/dw-skills/dw-skills/$version"
  mkdir -p "$cache/skills" "$cache/scripts/runtime"
  i=1; while [ "$i" -le 17 ]; do mkdir -p "$cache/skills/s$i"; touch "$cache/skills/s$i/SKILL.md"; i=$((i + 1)); done
  i=1; while [ "$i" -le 5 ]; do mkdir -p "$cache/skills/s$i/agents"; touch "$cache/skills/s$i/agents/openai.yaml"; i=$((i + 1)); done
  i=1; while [ "$i" -le 5 ]; do touch "$cache/scripts/runtime/h$i.sh"; chmod +x "$cache/scripts/runtime/h$i.sh"; i=$((i + 1)); done
}

make_claude_cache() {
  local name="$1" skills="$2" runtime="$3" path i
  path="$TMP/claude-$name"
  mkdir -p "$path/skills" "$path/scripts/runtime"
  i=1; while [ "$i" -le "$skills" ]; do mkdir -p "$path/skills/s$i"; touch "$path/skills/s$i/SKILL.md"; i=$((i + 1)); done
  i=1; while [ "$i" -le "$runtime" ]; do touch "$path/scripts/runtime/h$i.sh"; chmod +x "$path/scripts/runtime/h$i.sh"; i=$((i + 1)); done
  printf '%s\n' "$path"
}

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }
contains() {
  local name="$1" output="$2" needle="$3"
  case "$output" in *"$needle"*) note_pass "$name" ;; *) note_fail "$name" "missing '$needle'" ;; esac
}

# --platform with no value must exit 2 fast, never loop forever. Portable
# watchdog (no `timeout` on macOS): kill the run if it outlives the deadline.
( cd "$REPO" && bash "$DOCTOR" --platform >/dev/null 2>&1 ) & doctor_pid=$!
( sleep 5; kill -9 "$doctor_pid" 2>/dev/null ) & watch_pid=$!
wait "$doctor_pid" 2>/dev/null; rc=$?
kill "$watch_pid" 2>/dev/null
if [ "$rc" -eq 2 ]; then note_pass "platform-missing-value"; else note_fail "platform-missing-value" "want exit 2, got $rc (137 = hang killed)"; fi

out="$(cd "$REPO" && CODEX_CLI_VERSION=0.141.0 bash "$DOCTOR" --platform codex)"
contains "codex-unsupported" "$out" "unsupported 0.141.0; dw-skills requires Codex CLI >=0.142.0"

make_codex_cache 0.4.0
CODEX_FIXTURE="$TMP/codex.json"; export CODEX_FIXTURE
jq -n '{installed:[{pluginId:"dw-skills@dw-skills",version:"0.4.0",installed:true,enabled:true}]}' >"$CODEX_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-complete-state" "$out" "installed and enabled (version 0.4.0)"
contains "codex-complete-cache" "$out" "complete: 17 skills, 5 policies, 5 executable runtime helpers"

jq -n '{installed:[]}' >"$CODEX_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-missing" "$out" "dw-skills@dw-skills is not installed"

jq -n '{installed:[{pluginId:"dw-skills@dw-skills",version:"0.4.0",installed:true,enabled:false}]}' >"$CODEX_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-disabled" "$out" "installed but disabled"

make_codex_cache 0.3.0
jq -n '{installed:[{pluginId:"dw-skills@dw-skills",version:"0.3.0",installed:true,enabled:true}]}' >"$CODEX_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-wrong-version" "$out" "installed 0.3.0; expected 0.4.0"

rm "$CODEX_HOME/plugins/cache/dw-skills/dw-skills/0.4.0/skills/s17/SKILL.md"
jq -n '{installed:[{pluginId:"dw-skills@dw-skills",version:"0.4.0",installed:true,enabled:true}]}' >"$CODEX_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-broken-cache" "$out" "incomplete: skills=16/17"

# Codex hook wiring: valid JSON alone must not report OK — each referenced
# script has to resolve and be executable, mirroring the Claude per-script check.
mkdir -p "$REPO/.codex/hooks"
hooks_cmd() { printf 'bash "$(git rev-parse --show-toplevel)/.codex/hooks/%s"' "$1"; }
jq -n --arg c "$(hooks_cmd ghost.sh)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]}]}}' >"$REPO/.codex/hooks.json"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-hook-missing" "$out" "missing: .codex/hooks/ghost.sh"

: >"$REPO/.codex/hooks/dull.sh"; chmod -x "$REPO/.codex/hooks/dull.sh"
jq -n --arg c "$(hooks_cmd dull.sh)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]}]}}' >"$REPO/.codex/hooks.json"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-hook-nonexec" "$out" "not executable: .codex/hooks/dull.sh"

chmod +x "$REPO/.codex/hooks/dull.sh"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-hook-ok" "$out" "[ OK ] Codex hook script"
contains "codex-hook-trust" "$out" "confirm hooks were approved in Codex"

jq -n '{hooks:{}}' >"$REPO/.codex/hooks.json"
out="$(cd "$REPO" && bash "$DOCTOR" --platform codex)"
contains "codex-hook-empty" "$out" "none wired in hooks.json"
rm -f "$REPO/.codex/hooks.json"

misc="$(make_claude_cache misc 5 0)"
planning="$(make_claude_cache planning 5 5)"
quality="$(make_claude_cache quality 7 1)"
CLAUDE_FIXTURE="$TMP/claude.json"; export CLAUDE_FIXTURE
jq -n --arg misc "$misc" --arg planning "$planning" --arg quality "$quality" '[
  {id:"dw-misc@dw-skills",version:"0.4.0",enabled:true,installPath:$misc},
  {id:"dw-planning@dw-skills",version:"0.4.0",enabled:true,installPath:$planning},
  {id:"dw-quality@dw-skills",version:"0.4.0",enabled:true,installPath:$quality}
]' >"$CLAUDE_FIXTURE"
out="$(cd "$REPO" && bash "$DOCTOR" --platform claude)"
contains "claude-complete-misc" "$out" "dw-misc cache"
contains "claude-complete-quality" "$out" "complete: 7 skills, 1 runtime helpers"

jq 'map(select(.id != "dw-quality@dw-skills"))' "$CLAUDE_FIXTURE" >"$TMP/claude-missing.json"
CLAUDE_FIXTURE="$TMP/claude-missing.json" out="$(cd "$REPO" && CLAUDE_FIXTURE="$TMP/claude-missing.json" bash "$DOCTOR" --platform claude)"
contains "claude-missing" "$out" "dw-quality@dw-skills"
contains "claude-missing-detail" "$out" "not installed"

jq 'map(if .id == "dw-misc@dw-skills" then .enabled=false else . end)' "$TMP/claude.json" >"$TMP/claude-disabled.json"
out="$(cd "$REPO" && CLAUDE_FIXTURE="$TMP/claude-disabled.json" bash "$DOCTOR" --platform claude)"
contains "claude-disabled" "$out" "installed but disabled"

jq 'map(if .id == "dw-planning@dw-skills" then .version="0.3.0" else . end)' "$TMP/claude.json" >"$TMP/claude-wrong.json"
out="$(cd "$REPO" && CLAUDE_FIXTURE="$TMP/claude-wrong.json" bash "$DOCTOR" --platform claude)"
contains "claude-wrong-version" "$out" "installed 0.3.0; expected 0.4.0"

rm "$quality/skills/s7/SKILL.md"
out="$(cd "$REPO" && CLAUDE_FIXTURE="$TMP/claude.json" bash "$DOCTOR" --platform claude)"
contains "claude-broken-cache" "$out" "incomplete: skills=6/7"

echo
echo "doctor self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
