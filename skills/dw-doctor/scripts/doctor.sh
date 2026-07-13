#!/usr/bin/env bash
# dw-doctor — read-only environment diagnostic for a dw-* repo.
#
# Checks whether the tools a dw-* repo assumes are present and whether its
# hooks/skills will actually work, then prints one line per check
# (OK / WARN / FAIL) with a fix hint. It diagnoses the CURRENT git repo
# (resolved from cwd), not the skill's own location.
#
# READ-ONLY: it never installs anything and never edits a file. It runs
# `command -v`, `--version`, and host `plugin list --json` probes, then reads files. Exits 0 always — the
# report text carries the verdict.
#
# Stack checks are conditional on what the repo declares (package.json /
# Gemfile / tsconfig.json / DW.local.md / legacy CLAUDE.local.md), mirroring how the hooks resolve
# their commands — so nothing about a stack is hardcoded.
set -uo pipefail

DW_SKILLS_VERSION="0.4.0"
DW_CODEX_MIN_VERSION="0.142.0"

PLATFORM=auto
while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform)
      [ "$#" -ge 2 ] || { printf 'usage: doctor.sh [--platform auto|claude|codex|both]\n' >&2; exit 2; }
      PLATFORM="$2"; shift 2 ;;
    --platform=*) PLATFORM="${1#*=}"; shift ;;
    *) printf 'usage: doctor.sh [--platform auto|claude|codex|both]\n' >&2; exit 2 ;;
  esac
done
case "$PLATFORM" in auto|claude|codex|both) ;; *) printf 'invalid platform: %s\n' "$PLATFORM" >&2; exit 2 ;; esac

# --- output helpers (color only on a TTY) ------------------------------------
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_OK=; C_WARN=; C_FAIL=; C_DIM=; C_RST=
fi

OK=0; WARN=0; FAIL=0

report() {
  # report <ok|warn|fail|info> <label> [message]
  local level="$1" label="$2" msg="${3:-}"
  case "$level" in
    ok)   OK=$((OK + 1));     printf '  %s[ OK ]%s %-22s %s\n' "$C_OK"   "$C_RST" "$label" "$msg" ;;
    warn) WARN=$((WARN + 1)); printf '  %s[WARN]%s %-22s %s\n' "$C_WARN" "$C_RST" "$label" "$msg" ;;
    fail) FAIL=$((FAIL + 1)); printf '  %s[FAIL]%s %-22s %s\n' "$C_FAIL" "$C_RST" "$label" "$msg" ;;
    info) printf '  %s%-28s %s%s\n' "$C_DIM" "$label" "$msg" "$C_RST" ;;
  esac
}

group() { printf '\n%s%s%s\n' "$C_DIM" "$1" "$C_RST"; }

have() { command -v "$1" >/dev/null 2>&1; }

version_at_least() {
  # Numeric semver comparison, compatible with macOS Bash 3.2.
  local current="$1" minimum="$2" current_major current_minor current_patch minimum_major minimum_minor minimum_patch
  IFS=. read -r current_major current_minor current_patch <<EOF
$current
EOF
  IFS=. read -r minimum_major minimum_minor minimum_patch <<EOF
$minimum
EOF
  current_patch="${current_patch%%[^0-9]*}"
  minimum_patch="${minimum_patch%%[^0-9]*}"
  [ "${current_major:-0}" -gt "${minimum_major:-0}" ] && return 0
  [ "${current_major:-0}" -lt "${minimum_major:-0}" ] && return 1
  [ "${current_minor:-0}" -gt "${minimum_minor:-0}" ] && return 0
  [ "${current_minor:-0}" -lt "${minimum_minor:-0}" ] && return 1
  [ "${current_patch:-0}" -ge "${minimum_patch:-0}" ]
}

count_files() {
  local root="$1" pattern="$2"
  [ -d "$root" ] || { printf '0\n'; return; }
  find "$root" -type f -name "$pattern" | wc -l | tr -d ' '
}

check_codex_plugin() {
  local json plugin version cache skills policies runtime nonexec cli_line cli_version
  if ! have codex; then
    report warn "Codex plugin" "CLI absent — dw-skills installation cannot be inspected"
    return
  fi
  cli_line="$(codex --version 2>/dev/null | head -n1)"
  cli_version="$(printf '%s\n' "$cli_line" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  report ok "codex" "$cli_line"
  if [ -z "$cli_version" ] || ! version_at_least "$cli_version" "$DW_CODEX_MIN_VERSION"; then
    report warn "Codex support" "unsupported ${cli_version:-unknown}; dw-skills requires Codex CLI >=$DW_CODEX_MIN_VERSION"
    return
  fi
  if ! have jq; then
    report warn "Codex plugin" "state skipped — jq is required to parse plugin list --json"
    return
  fi
  if ! json="$(codex plugin list --json 2>/dev/null)"; then
    report warn "Codex plugin" "plugin list --json failed"
    return
  fi
  plugin="$(jq -c '[.installed[]? | select(.pluginId == "dw-skills@dw-skills")][0] // empty' <<<"$json")"
  if [ -z "$plugin" ]; then
    report warn "Codex plugin" "dw-skills@dw-skills is not installed"
    return
  fi
  if [ "$(jq -r '.installed // false' <<<"$plugin")" != true ]; then
    report warn "Codex plugin" "entry exists but is not installed"
    return
  fi
  version="$(jq -r '.version // empty' <<<"$plugin")"
  if [ "$(jq -r '.enabled // false' <<<"$plugin")" != true ]; then
    report warn "Codex plugin" "installed but disabled (version ${version:-unknown})"
  else
    report ok "Codex plugin" "installed and enabled (version ${version:-unknown})"
  fi
  if [ "$version" = "$DW_SKILLS_VERSION" ]; then
    report ok "Codex version" "$version"
  else
    report warn "Codex version" "installed ${version:-unknown}; expected $DW_SKILLS_VERSION"
  fi

  cache="${CODEX_HOME:-$HOME/.codex}/plugins/cache/dw-skills/dw-skills/$version"
  if [ ! -d "$cache" ]; then
    report fail "Codex cache" "missing for installed version at $cache"
    return
  fi
  skills="$(count_files "$cache/skills" SKILL.md)"
  policies="$(count_files "$cache/skills" openai.yaml)"
  runtime="$(count_files "$cache/scripts/runtime" '*.sh')"
  nonexec="$(find "$cache/scripts/runtime" -type f -name '*.sh' ! -perm -u+x 2>/dev/null | head -n1)"
  if [ "$skills" = 17 ] && [ "$policies" = 5 ] && [ "$runtime" = 5 ] && [ -z "$nonexec" ]; then
    report ok "Codex cache" "complete: 17 skills, 5 policies, 5 executable runtime helpers"
  else
    report fail "Codex cache" "incomplete: skills=$skills/17 policies=$policies/5 runtime=$runtime/5$([ -n "$nonexec" ] && echo ', non-executable helper found')"
  fi
}

check_claude_plugins() {
  local json id plugin enabled version install_path expected_skills expected_runtime skills runtime nonexec
  if ! have claude; then
    report warn "Claude plugins" "CLI absent — installations cannot be inspected"
    return
  fi
  report ok "claude" "$(claude --version 2>/dev/null | head -n1)"
  if ! have jq; then
    report warn "Claude plugins" "state skipped — jq is required to parse plugin list --json"
    return
  fi
  if ! json="$(claude plugin list --json 2>/dev/null)"; then
    report warn "Claude plugins" "plugin list --json failed"
    return
  fi
  for id in dw-misc@dw-skills dw-planning@dw-skills dw-quality@dw-skills; do
    plugin="$(jq -c --arg id "$id" '[.[]? | select(.id == $id)][0] // empty' <<<"$json")"
    if [ -z "$plugin" ]; then
      report warn "$id" "not installed"
      continue
    fi
    enabled="$(jq -r '.enabled // false' <<<"$plugin")"
    version="$(jq -r '.version // empty' <<<"$plugin")"
    install_path="$(jq -r '.installPath // empty' <<<"$plugin")"
    if [ "$enabled" = true ]; then
      report ok "$id" "installed and enabled (version ${version:-unknown})"
    else
      report warn "$id" "installed but disabled (version ${version:-unknown})"
    fi
    if [ "$version" != "$DW_SKILLS_VERSION" ]; then
      report warn "${id%@*} version" "installed ${version:-unknown}; expected $DW_SKILLS_VERSION"
    fi
    case "$id" in
      dw-misc@*) expected_skills=5; expected_runtime=0 ;;
      dw-planning@*) expected_skills=5; expected_runtime=5 ;;
      dw-quality@*) expected_skills=7; expected_runtime=1 ;;
    esac
    if [ -z "$install_path" ] || [ ! -d "$install_path" ]; then
      report fail "${id%@*} cache" "installPath missing or unreadable: ${install_path:-unset}"
      continue
    fi
    skills="$(count_files "$install_path/skills" SKILL.md)"
    runtime="$(count_files "$install_path/scripts/runtime" '*.sh')"
    nonexec="$(find "$install_path/scripts/runtime" -type f -name '*.sh' ! -perm -u+x 2>/dev/null | head -n1)"
    if [ "$skills" = "$expected_skills" ] && [ "$runtime" = "$expected_runtime" ] && [ -z "$nonexec" ]; then
      report ok "${id%@*} cache" "complete: $skills skills, $runtime runtime helpers"
    else
      report fail "${id%@*} cache" "incomplete: skills=$skills/$expected_skills runtime=$runtime/$expected_runtime$([ -n "$nonexec" ] && echo ', non-executable helper found')"
    fi
  done
}

# ver_ge MIN CUR → true when CUR >= MIN (version-sorted; MIN sorts first or ties).
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

# --- locate the target repo ---------------------------------------------------
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

printf '%sdw-doctor%s — read-only environment diagnostic\n' "$C_DIM" "$C_RST"
printf '%srepo: %s%s\n' "$C_DIM" "$ROOT" "$C_RST"
if [ "$PLATFORM" = auto ]; then
  if [ -d "$ROOT/.claude" ] && [ -d "$ROOT/.codex" ]; then PLATFORM=both
  elif [ -d "$ROOT/.codex" ]; then PLATFORM=codex
  else PLATFORM=claude
  fi
fi
printf '%splatform: %s%s\n' "$C_DIM" "$PLATFORM" "$C_RST"

# --- core tools ---------------------------------------------------------------
group "Core tools"
if have git; then
  report ok "git" "$(git --version 2>/dev/null | head -n1)"
else
  report fail "git" "missing — install: xcode-select --install (or brew install git)"
fi
if have jq; then
  report ok "jq" "$(jq --version 2>/dev/null)"
else
  report fail "jq" "MISSING — dw hook scripts silently no-op without it. Install: brew install jq"
fi

# --- optional tools -----------------------------------------------------------
group "Optional tools"
if have gh; then
  report ok "gh" "$(gh --version 2>/dev/null | head -n1)"
else
  report warn "gh" "absent — dw-git PRs & dw-quality 'gh pr diff' need it. Install: brew install gh"
fi

# --- JavaScript / TypeScript (only if package.json) ---------------------------
pkg="$ROOT/package.json"
group "JavaScript / TypeScript"
if [ ! -f "$pkg" ]; then
  report info "—" "no package.json — JS/TS checks skipped"
elif have jq && ! jq empty "$pkg" 2>/dev/null; then
  report fail "package.json" "present but not valid JSON"
else
  # node vs engines.node
  if have node; then
    cur="$(node -v 2>/dev/null | sed 's/^v//')"
    min=""
    have jq && min="$(jq -r '.engines.node // empty' "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)"
    if [ -n "$min" ]; then
      if ver_ge "$min" "$cur"; then
        report ok "node" "$cur (engines: >=$min)"
      else
        report warn "node" "$cur < required $min — upgrade (see .nvmrc, or brew install node)"
      fi
    else
      report ok "node" "$cur"
    fi
  else
    report fail "node" "missing — install via nvm (.nvmrc) or brew install node"
  fi

  # pnpm vs packageManager
  pm=""; have jq && pm="$(jq -r '.packageManager // empty' "$pkg" 2>/dev/null)"
  want_pnpm=0; pmver=""
  case "$pm" in pnpm@*) want_pnpm=1; pmver="${pm##*@}"; pmver="${pmver%%+*}" ;; esac
  if [ -f "$ROOT/pnpm-lock.yaml" ] || [ "$want_pnpm" -eq 1 ]; then
    if have pnpm; then
      cur_pnpm="$(pnpm -v 2>/dev/null)"
      if [ "$want_pnpm" -eq 1 ] && [ -n "$pmver" ] && [ "$cur_pnpm" != "$pmver" ]; then
        report warn "pnpm" "$cur_pnpm (packageManager pins $pmver — run: corepack enable)"
      else
        report ok "pnpm" "${cur_pnpm:-present}"
      fi
    else
      report fail "pnpm" "missing — hooks enforce pnpm. Install: corepack enable (or npm i -g pnpm)"
    fi
  fi

  # declared deps actually installed
  if have jq; then
    ndeps="$(jq -r '((.dependencies // {}) + (.devDependencies // {})) | length' "$pkg" 2>/dev/null || echo 0)"
    if [ "${ndeps:-0}" -gt 0 ] && [ ! -d "$ROOT/node_modules" ]; then
      report warn "node_modules" "absent but deps declared — run: pnpm install"
    else
      for t in agnix prettier; do
        if jq -e --arg t "$t" '(.devDependencies // {})[$t] // (.dependencies // {})[$t]' "$pkg" >/dev/null 2>&1; then
          if [ -x "$ROOT/node_modules/.bin/$t" ]; then
            report ok "$t" "installed"
          else
            report warn "$t" "declared but not in node_modules — run: pnpm install"
          fi
        fi
      done
    fi
  fi

  # tsc — only if the repo asks for typechecking
  has_ts=0
  [ -f "$ROOT/tsconfig.json" ] && has_ts=1
  if have jq && jq -e '.scripts.typecheck' "$pkg" >/dev/null 2>&1; then has_ts=1; fi
  if [ "$has_ts" -eq 1 ]; then
    if [ -x "$ROOT/node_modules/.bin/tsc" ] || { have jq && jq -e '(.devDependencies // {}).typescript // (.dependencies // {}).typescript' "$pkg" >/dev/null 2>&1; }; then
      report ok "tsc" "typescript available"
    else
      report warn "tsc" "tsconfig/typecheck present but no typescript dep — run: pnpm install (or add typescript)"
    fi
  fi
fi

# --- Ruby (only if Gemfile) ---------------------------------------------------
gemfile="$ROOT/Gemfile"
if [ -f "$gemfile" ]; then
  group "Ruby"
  if have bundle; then
    report ok "bundle" "$(bundle --version 2>/dev/null | head -n1)"
  else
    report warn "bundle" "missing — install: gem install bundler"
  fi
  if grep -qE "^[[:space:]]*gem[[:space:]]+[\"']standard[\"']" "$gemfile"; then
    report info "lint" "Gemfile declares standard → bundle exec standardrb"
  elif grep -qE "^[[:space:]]*gem[[:space:]]+[\"']rubocop" "$gemfile"; then
    report info "lint" "Gemfile declares rubocop → bundle exec rubocop"
  else
    report info "lint" "no rubocop/standard in Gemfile — hook no-ops unless DW.local.md or legacy CLAUDE.local.md sets one"
  fi
fi

# --- repo structure -----------------------------------------------------------
group "Structure"
for common in .ai AGENTS.md DW.local.md; do
  if [ -e "$ROOT/$common" ]; then report ok "$common" "present"
  else report warn "$common" "absent — run dw-bootstrap"; fi
done
if [ -f "$ROOT/AGENTS.override.md" ]; then
  report warn "AGENTS.override.md" "present at repo root — it masks AGENTS.md"
fi
if [ -f "$ROOT/CLAUDE.local.md" ] && [ ! -f "$ROOT/DW.local.md" ]; then
  report warn "legacy profile" "CLAUDE.local.md needs migration to DW.local.md"
fi

settings="$ROOT/.claude/settings.json"
if [ "$PLATFORM" = claude ] || [ "$PLATFORM" = both ]; then
if [ -f "$settings" ]; then
  if have jq && ! jq empty "$settings" 2>/dev/null; then
    report fail ".claude/settings.json" "invalid JSON"
  else
    report ok ".claude/settings.json" "present"
    if have jq; then
      found_hook=0
      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        script_path="$(printf '%s' "$cmd" | grep -oE '[^" ]*\.sh' | head -n1)"
        [ -z "$script_path" ] && continue
        found_hook=1
        script_path="${script_path//\$\{CLAUDE_PROJECT_DIR\}/$ROOT}"
        script_path="${script_path//\$CLAUDE_PROJECT_DIR/$ROOT}"
        case "$script_path" in /*) ;; *) script_path="$ROOT/$script_path" ;; esac
        rel="${script_path#"$ROOT"/}"
        if [ ! -f "$script_path" ]; then
          report fail "hook script" "missing: $rel — that guardrail won't run"
        elif [ ! -x "$script_path" ]; then
          report fail "hook script" "not executable: $rel — fix: chmod +x"
        else
          report ok "hook script" "$rel"
        fi
      done < <(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' "$settings" 2>/dev/null)
      [ "$found_hook" -eq 0 ] && report info "hooks" "none wired in settings.json"
    else
      report warn ".claude/hooks" "skipped (needs jq to parse settings.json)"
    fi
  fi
else
  report warn ".claude/settings.json" "absent — no hooks/guardrails in this repo"
fi
fi

if [ "$PLATFORM" = codex ] || [ "$PLATFORM" = both ]; then
  codex_hooks="$ROOT/.codex/hooks.json"
  if [ -f "$codex_hooks" ]; then
    if ! have jq; then
      report warn ".codex/hooks.json" "skipped (needs jq to parse)"
    elif ! jq empty "$codex_hooks" 2>/dev/null; then
      report fail ".codex/hooks.json" "invalid JSON"
    else
      report ok ".codex/hooks.json" "present and valid JSON"
      # Parity with the Claude per-script check above: valid JSON is not enough —
      # enumerate every wired command and verify each script resolves and is
      # executable, else that guardrail silently never runs.
      found_hook=0
      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        cmd="${cmd//\$(git rev-parse --show-toplevel)/$ROOT}"
        script_path="$(printf '%s' "$cmd" | grep -oE "[^'\" ]*\.sh" | head -n1)"
        [ -z "$script_path" ] && continue
        found_hook=1
        case "$script_path" in /*) ;; *) script_path="$ROOT/$script_path" ;; esac
        rel="${script_path#"$ROOT"/}"
        if [ ! -f "$script_path" ]; then
          report fail "Codex hook script" "missing: $rel — that guardrail won't run"
        elif [ ! -x "$script_path" ]; then
          report fail "Codex hook script" "not executable: $rel — fix: chmod +x"
        else
          report ok "Codex hook script" "$rel"
        fi
      done < <(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' "$codex_hooks" 2>/dev/null)
      [ "$found_hook" -eq 0 ] && report warn "Codex hooks" "none wired in hooks.json — guardrails inactive"
    fi
  else
    report warn ".codex/hooks.json" "absent — Codex guardrails are not enabled"
  fi
  if [ -f "$ROOT/.codex/config.toml" ] && grep -qE 'hooks[[:space:]]*=[[:space:]]*false' "$ROOT/.codex/config.toml"; then
    report warn "Codex hooks" "explicitly disabled in .codex/config.toml"
  fi
  # Correctly-wired hooks still won't fire until Codex's per-hook trust prompt is
  # approved; that state lives outside the repo and can't be read here. Flag it so
  # a green wiring check doesn't imply the guardrails are actually live.
  [ -f "$codex_hooks" ] && report info "Codex hook trust" "activation needs approval on first use — not verifiable here; confirm hooks were approved in Codex"
  report warn ".env guardrail" "Codex protection is best-effort; built-in reads are not all intercepted"
fi

# --- installed plugin state ---------------------------------------------------
group "Installed plugins"
if [ "$PLATFORM" = codex ] || [ "$PLATFORM" = both ]; then check_codex_plugin; fi
if [ "$PLATFORM" = claude ] || [ "$PLATFORM" = both ]; then check_claude_plugins; fi

# --- plugins (opportunistic: only a marketplace repo has this) ----------------
mkt="$ROOT/.claude-plugin/marketplace.json"
if [ -f "$mkt" ]; then
  group "Plugins (marketplace repo)"
  if have jq; then
    n="$(jq '.plugins | length' "$mkt" 2>/dev/null || echo '?')"
    report ok "marketplace.json" "$n plugin(s) declared"
    mism=0
    while IFS=$'\t' read -r name source mp_v; do
      [ -z "$name" ] && continue
      pj="$ROOT/${source#./}/.claude-plugin/plugin.json"
      if [ ! -f "$pj" ]; then
        report warn "$name" "plugin.json missing at ${pj#"$ROOT"/}"; mism=1; continue
      fi
      pj_v="$(jq -r '.version' "$pj" 2>/dev/null)"
      if [ "$mp_v" != "$pj_v" ]; then
        report warn "$name" "version drift: marketplace=$mp_v vs plugin.json=$pj_v"; mism=1
      fi
    done < <(jq -r '.plugins[] | [.name, .source, .version] | @tsv' "$mkt" 2>/dev/null)
    [ "$mism" -eq 0 ] && report ok "version sync" "all in sync (full check: pnpm validate:manifests)"
  else
    report warn "marketplace.json" "present but skipped (needs jq)"
  fi
fi

# --- summary ------------------------------------------------------------------
group "Summary"
printf '  %d OK, %d warning(s), %d failure(s)\n' "$OK" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  %sAction needed:%s resolve the [FAIL] lines above — start with jq/git, they gate the rest.\n' "$C_FAIL" "$C_RST"
fi
printf '  %sRead-only: nothing was installed or modified.%s\n' "$C_DIM" "$C_RST"
exit 0
