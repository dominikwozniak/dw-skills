#!/usr/bin/env bash
# Self-test for safe, multi-file lint hook dispatch. bash 3.2 safe.
set -uo pipefail
export LC_ALL=C

command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS="$ROOT/skills/dw-bootstrap/references/templates/hooks"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
mkdir -p "$REPO/src" "$REPO/bin" "$TMP/outside"
git -C "$REPO" init -q
touch "$REPO/src/a.ts" "$REPO/src/b.js" "$REPO/src/c.rb" "$REPO/src/skip.txt" "$TMP/outside/nope.ts"

cat >"$REPO/bin/dw-lint" <<'SH'
#!/usr/bin/env bash
printf 'dw:%s\n' "$*" >>"$HOOK_LOG"
SH
cat >"$REPO/bin/legacy-lint" <<'SH'
#!/usr/bin/env bash
printf 'legacy:%s\n' "$*" >>"$HOOK_LOG"
SH
cat >"$REPO/bin/agents-lint" <<'SH'
#!/usr/bin/env bash
printf 'agents:%s\n' "$*" >>"$HOOK_LOG"
SH
chmod +x "$REPO/bin/"*
export PATH="$REPO/bin:$PATH"
export HOOK_LOG="$TMP/hook.log"

PASS=0
FAIL=0
note_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
note_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1 — $2"; }
assert_eq() {
  local name="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then note_pass "$name"; else note_fail "$name" "want '$want', got '$got'"; fi
}

run_patch() {
  local hook="$1" patch="$2"
  (cd "$REPO" && jq -n --arg command "$patch" '{tool_name:"apply_patch",tool_input:{command:$command}}' | bash "$hook")
}
run_file() {
  local hook="$1" path="$2"
  (cd "$REPO" && jq -n --arg path "$path" '{tool_name:"Edit",tool_input:{file_path:$path}}' | bash "$hook")
}

printf '%s\n' '- **Lint command**: `dw-lint`' >"$REPO/DW.local.md"
printf '%s\n' '- **Lint command**: `legacy-lint`' >"$REPO/CLAUDE.local.md"
printf '%s\n' '- **Lint command**: `agents-lint`' >"$REPO/AGENTS.md"

PATCH="*** Begin Patch
*** Update File: src/a.ts
*** Update File: src/b.js
*** Update File: src/c.rb
*** Update File: src/skip.txt
*** Update File: src/a.ts
*** Delete File: src/deleted.ts
*** Update File: $TMP/outside/nope.ts
*** End Patch"

: >"$HOOK_LOG"
run_patch "$HOOKS/lint-on-edit.sh" "$PATCH"
js_line="$(cat "$HOOK_LOG")"
case "$js_line" in
  dw:*src/a.ts*src/b.js*) note_pass "codex-multifile-js-dedup" ;;
  *) note_fail "codex-multifile-js-dedup" "$js_line" ;;
esac
case "$js_line" in *src/a.ts*src/a.ts*) note_fail "js-each-path-once" "$js_line" ;; *) note_pass "js-each-path-once" ;; esac
assert_eq "js-single-invocation" "1" "$(wc -l <"$HOOK_LOG" | tr -d ' ')"
case "$js_line" in *c.rb*|*skip.txt*|*deleted.ts*|*nope.ts*) note_fail "js-filtering" "$js_line" ;; *) note_pass "js-filtering" ;; esac
case "$js_line" in legacy:*|agents:*) note_fail "dw-local-precedence" "$js_line" ;; dw:*) note_pass "dw-local-precedence" ;; esac

: >"$HOOK_LOG"
run_patch "$HOOKS/lint-on-edit-rb.sh" "$PATCH"
rb_line="$(cat "$HOOK_LOG")"
case "$rb_line" in dw:*src/c.rb*) note_pass "codex-ruby-only" ;; *) note_fail "codex-ruby-only" "$rb_line" ;; esac
assert_eq "ruby-single-invocation" "1" "$(wc -l <"$HOOK_LOG" | tr -d ' ')"

: >"$HOOK_LOG"
run_file "$HOOKS/lint-on-edit.sh" "$REPO/src/a.ts"
case "$(cat "$HOOK_LOG")" in dw:*src/a.ts*) note_pass "claude-file-path" ;; *) note_fail "claude-file-path" "not dispatched" ;; esac

rm "$REPO/DW.local.md" "$REPO/CLAUDE.local.md"
: >"$HOOK_LOG"
run_file "$HOOKS/lint-on-edit.sh" "$REPO/src/a.ts"
assert_eq "agents-not-executed" "0" "$(wc -l <"$HOOK_LOG" | tr -d ' ')"

printf '%s\n' '- **Lint command**: `dw-lint; touch PWNED`' >"$REPO/DW.local.md"
: >"$HOOK_LOG"
run_file "$HOOKS/lint-on-edit.sh" "$REPO/src/a.ts" >/dev/null 2>&1
rc=$?
assert_eq "metacharacters-rejected" "2" "$rc"
if [ ! -e "$REPO/PWNED" ]; then note_pass "rejected-command-not-run"; else note_fail "rejected-command-not-run" "PWNED exists"; fi

if grep -En '(^|[^[:alnum:]_])eval([^[:alnum:]_]|$)' "$HOOKS"/*.sh >/dev/null; then
  note_fail "no-eval" "eval token found in hook templates"
else
  note_pass "no-eval"
fi

echo
echo "hook-runtime self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
