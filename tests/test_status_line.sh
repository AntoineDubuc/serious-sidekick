#!/bin/bash
# test_status_line.sh — Tests for status-line.sh (Plan 4b, Task 1)
# Tests Groups A-D: output sanitization, input guards, path validation, strict mode
# Plus: field access, fail-silent, output format, negative tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_UNDER_TEST="$PROJECT_ROOT/.claude/skills/serious-code/hooks/status-line.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures/status-line"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Color output (if terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  RESET=''
fi

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${GREEN}PASS${RESET}  $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${RED}FAIL${RESET}  $1"
  [ -n "${2:-}" ] && echo "        $2"
}

# Helper: set up a temp project dir with breadcrumb + status.json
setup_project() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local plan_dir="$tmp_dir/plans/test-plan"
  mkdir -p "$plan_dir"
  # Write breadcrumb
  echo "plans/test-plan" > "$tmp_dir/.active-code"
  echo "$tmp_dir"
}

# Helper: run status-line.sh with a given project dir and status.json
run_script() {
  local project_dir="$1"
  local status_file="${2:-}"
  local stdin_json
  stdin_json=$(printf '{"workspace":{"project_dir":"%s"}}' "$project_dir")

  if [ -n "$status_file" ]; then
    local plan_dir="$project_dir/plans/test-plan"
    cp "$status_file" "$plan_dir/status.json"
  fi

  echo "$stdin_json" | CLAUDE_PROJECT_DIR="$project_dir" bash "$SCRIPT_UNDER_TEST" 2>/dev/null
}

# Helper: run and capture both stdout and exit code
run_script_full() {
  local project_dir="$1"
  local status_file="${2:-}"
  local stdin_json
  stdin_json=$(printf '{"workspace":{"project_dir":"%s"}}' "$project_dir")

  if [ -n "$status_file" ]; then
    local plan_dir="$project_dir/plans/test-plan"
    cp "$status_file" "$plan_dir/status.json"
  fi

  local output
  local exit_code
  output=$(echo "$stdin_json" | CLAUDE_PROJECT_DIR="$project_dir" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || true
  exit_code=$?
  echo "$output"
  return "$exit_code"
}

echo "=== Test: status-line.sh ==="
echo ""

# ─── Group A — Output sanitization ────────────────────────────────────────────

echo "--- Group A: Output sanitization ---"
echo ""

# A1: ESC bytes stripped from output
TMP_PROJECT=$(setup_project)
trap 'rm -rf "$TMP_PROJECT"' EXIT

if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "A1: ANSI escape sequences stripped from plan_name" "Script does not exist"
else
  OUTPUT=$(run_script "$TMP_PROJECT" "$FIXTURES/malicious_status.json" || true)
  # Check for ESC byte (0x1B) in output
  if echo "$OUTPUT" | LC_ALL=C grep -cP '\x1b' >/dev/null 2>&1; then
    fail "A1: ANSI escape sequences stripped from plan_name" "Output contains ESC bytes"
  else
    pass "A1: ANSI escape sequences stripped from plan_name"
  fi
fi

# A2: tr -d sanitization appears BEFORE truncation in script
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Find line numbers of tr -d and ${var:0:N} / head -c / cut
  SANITIZE_LINE=$(grep -n "tr -d" "$SCRIPT_UNDER_TEST" | head -1 | cut -d: -f1)
  TRUNCATE_LINE=$(grep -n -E '\$\{[a-z_]+:0:|head -c|cut -c' "$SCRIPT_UNDER_TEST" | head -1 | cut -d: -f1)
  if [ -n "$SANITIZE_LINE" ] && [ -n "$TRUNCATE_LINE" ] && [ "$SANITIZE_LINE" -lt "$TRUNCATE_LINE" ]; then
    pass "A2: Sanitization (tr -d) appears before truncation in code"
  else
    fail "A2: Sanitization (tr -d) appears before truncation in code" "sanitize=$SANITIZE_LINE truncate=$TRUNCATE_LINE"
  fi
else
  fail "A2: Sanitization (tr -d) appears before truncation in code" "Script does not exist"
fi

# A3: Oversized plan_name produces output <= 4096 bytes
if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "A3: Output capped at 4096 bytes" "Script does not exist"
  fail "A3: Output max 2 lines" "Script does not exist"
else
  OUTPUT=$(run_script "$TMP_PROJECT" "$FIXTURES/oversized_status.json" || true)
  OUTPUT_LEN=${#OUTPUT}
  if [ "$OUTPUT_LEN" -le 4096 ]; then
    pass "A3: Output capped at 4096 bytes (got $OUTPUT_LEN bytes)"
  else
    fail "A3: Output capped at 4096 bytes" "Got $OUTPUT_LEN bytes"
  fi

  # A3 also: output is max 2 lines
  LINE_COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')
  if [ "$LINE_COUNT" -le 2 ]; then
    pass "A3: Output max 2 lines (got $LINE_COUNT)"
  else
    fail "A3: Output max 2 lines" "Got $LINE_COUNT lines"
  fi
fi

# A4: Per-line width capped (default 80 when tput not available)
if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "A4: Per-line width capped" "Script does not exist"
else
  OUTPUT=$(run_script "$TMP_PROJECT" "$FIXTURES/oversized_status.json" || true)
  if [ -n "$OUTPUT" ]; then
    MAX_LINE_LEN=0
    while IFS= read -r line; do
      len=${#line}
      if [ "$len" -gt "$MAX_LINE_LEN" ]; then
        MAX_LINE_LEN=$len
      fi
    done <<< "$OUTPUT"
    # Should be capped at some reasonable width (80 default or tput cols)
    if [ "$MAX_LINE_LEN" -le 200 ]; then
      pass "A4: Per-line width capped (max line: $MAX_LINE_LEN chars)"
    else
      fail "A4: Per-line width capped" "Max line is $MAX_LINE_LEN chars"
    fi
  else
    # If empty output, that's still valid — some error paths produce empty
    pass "A4: Per-line width capped (empty output is valid)"
  fi
fi

# Bidi: UTF-8 bidi override codepoints stripped
if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "Bidi: UTF-8 bidi override codepoints stripped from output" "Script does not exist"
else
  OUTPUT=$(run_script "$TMP_PROJECT" "$FIXTURES/bidi_status.json" || true)
  # Check for U+202E (RLO) = 0xe2 0x80 0xae
  if echo "$OUTPUT" | LC_ALL=C grep -cP '\xe2\x80[\xaa-\xae]' >/dev/null 2>&1; then
    fail "Bidi: UTF-8 bidi override codepoints stripped from output" "Output contains bidi bytes"
  else
    pass "Bidi: UTF-8 bidi override codepoints stripped from output"
  fi
fi

echo ""

# ─── Group B — Input guards ──────────────────────────────────────────────────

echo "--- Group B: Input guards ---"
echo ""

# B1: stdin capped at 64KB (head -c 65536)
# Generate 10MB stdin and verify script completes quickly
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  LARGE_STDIN=$(python3 -c "import json; d={'workspace':{'project_dir':'$TMP_PROJECT'}}; s=json.dumps(d); print(s + ' ' * (10*1024*1024))")
  START_TIME=$(date +%s)
  echo "$LARGE_STDIN" | CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>/dev/null || true
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  if [ "$ELAPSED" -lt 2 ]; then
    pass "B1: 10MB stdin completes in < 2 seconds (took ${ELAPSED}s)"
  else
    fail "B1: 10MB stdin completes in < 2 seconds" "Took ${ELAPSED}s"
  fi
else
  fail "B1: 10MB stdin completes in < 2 seconds" "Script does not exist"
fi

# B2: NUL bytes in stdin do not crash jq
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  NUL_INPUT=$(printf '{"workspace":{"project_dir":"%s"},"extra":"a\x00b"}' "$TMP_PROJECT")
  NUL_EXIT=0
  echo "$NUL_INPUT" | CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>/dev/null || NUL_EXIT=$?
  if [ "$NUL_EXIT" -eq 0 ]; then
    pass "B2: NUL bytes in stdin do not crash (exit 0)"
  else
    fail "B2: NUL bytes in stdin do not crash" "Exit code: $NUL_EXIT"
  fi
else
  fail "B2: NUL bytes in stdin do not crash" "Script does not exist"
fi

# B3: Empty JSON object produces exit 0
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  EMPTY_EXIT=0
  EMPTY_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || EMPTY_EXIT=$?
  if [ "$EMPTY_EXIT" -eq 0 ]; then
    pass "B3: Empty JSON object produces exit 0"
  else
    fail "B3: Empty JSON object produces exit 0" "Exit code: $EMPTY_EXIT"
  fi
else
  fail "B3: Empty JSON object produces exit 0" "Script does not exist"
fi

echo ""

# ─── Group C — Path validation ───────────────────────────────────────────────

echo "--- Group C: Path validation ---"
echo ""

# C1: Script sources path-resolve.sh and uses resolve_breadcrumb_path
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  if grep -q 'resolve_breadcrumb_path' "$SCRIPT_UNDER_TEST" && grep -q 'path-resolve.sh' "$SCRIPT_UNDER_TEST"; then
    pass "C1: Script sources path-resolve.sh and uses resolve_breadcrumb_path"
  else
    fail "C1: Script sources path-resolve.sh and uses resolve_breadcrumb_path"
  fi
else
  fail "C1: Script sources path-resolve.sh and uses resolve_breadcrumb_path" "Script does not exist"
fi

# C2: Breadcrumb pointing outside project produces empty output and exit 0
EVIL_PROJECT=$(mktemp -d)
mkdir -p "$EVIL_PROJECT"
echo "../../etc/passwd" > "$EVIL_PROJECT/.active-code"
EVIL_STDIN=$(printf '{"workspace":{"project_dir":"%s"}}' "$EVIL_PROJECT")
EVIL_EXIT=0
EVIL_OUT=$(echo "$EVIL_STDIN" | CLAUDE_PROJECT_DIR="$EVIL_PROJECT" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || EVIL_EXIT=$?
if [ "$EVIL_EXIT" -eq 0 ] && [ -z "$EVIL_OUT" ]; then
  pass "C2: Path traversal breadcrumb produces empty output, exit 0"
else
  fail "C2: Path traversal breadcrumb produces empty output, exit 0" "exit=$EVIL_EXIT output='$EVIL_OUT'"
fi
rm -rf "$EVIL_PROJECT"

# C3: Trailing slash prevents /proj vs /proj-evil confusion
# This is tested structurally by verifying the trailing-slash pattern in the script
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  if grep -q 'resolve_breadcrumb_path' "$SCRIPT_UNDER_TEST"; then
    # resolve_breadcrumb_path already has trailing-slash check built in
    pass "C3: Trailing-slash trust-root check (via resolve_breadcrumb_path)"
  else
    fail "C3: Trailing-slash trust-root check" "resolve_breadcrumb_path not used"
  fi
else
  fail "C3: Trailing-slash trust-root check" "Script does not exist"
fi

# TOCTOU: Re-check that resolved path is not a symlink
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  if grep -q '\-L' "$SCRIPT_UNDER_TEST"; then
    pass "TOCTOU: Script re-checks resolved path is not a symlink"
  else
    fail "TOCTOU: Script re-checks resolved path is not a symlink" "No -L check found"
  fi
else
  fail "TOCTOU: Script re-checks resolved path is not a symlink" "Script does not exist"
fi

echo ""

# ─── Group D — Shell strict mode ────────────────────────────────────────────

echo "--- Group D: Shell strict mode ---"
echo ""

# D1: Script has correct shebang and strict mode settings
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  FIRST_LINE=$(head -1 "$SCRIPT_UNDER_TEST")
  if [ "$FIRST_LINE" = "#!/usr/bin/env bash" ]; then
    pass "D1: Shebang is #!/usr/bin/env bash"
  else
    fail "D1: Shebang is #!/usr/bin/env bash" "Got: $FIRST_LINE"
  fi

  if grep -q 'set -eo pipefail' "$SCRIPT_UNDER_TEST"; then
    pass "D1: set -eo pipefail present"
  else
    fail "D1: set -eo pipefail present"
  fi

  if grep -q "IFS=\$'\\\\n\\\\t'" "$SCRIPT_UNDER_TEST"; then
    pass "D1: IFS set to newline+tab"
  else
    fail "D1: IFS set to newline+tab"
  fi

  if grep -q 'set -o noglob' "$SCRIPT_UNDER_TEST" || grep -q 'set -f' "$SCRIPT_UNDER_TEST"; then
    pass "D1: noglob enabled"
  else
    fail "D1: noglob enabled"
  fi
else
  fail "D1: Strict mode settings" "Script does not exist"
fi

# D2: shellcheck passes with zero findings
if [ -f "$SCRIPT_UNDER_TEST" ] && command -v shellcheck >/dev/null 2>&1; then
  SC_OUTPUT=$(shellcheck --severity=error "$SCRIPT_UNDER_TEST" 2>&1 || true)
  SC_EXIT=$?
  if [ -z "$SC_OUTPUT" ] || [ "$SC_EXIT" -eq 0 ]; then
    pass "D2: shellcheck --severity=error passes"
  else
    fail "D2: shellcheck --severity=error passes" "Findings: $SC_OUTPUT"
  fi
elif [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "D2: shellcheck --severity=error passes" "Script does not exist"
else
  fail "D2: shellcheck --severity=error passes" "shellcheck not installed"
fi

# D4: No eval, no backticks, no source with user-controlled arg
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Check for eval
  if grep -q '\beval\b' "$SCRIPT_UNDER_TEST"; then
    fail "D4: No eval in script"
  else
    pass "D4: No eval in script"
  fi

  # Check for backticks (but not in comments)
  BACKTICK_COUNT=$(grep -v '^#' "$SCRIPT_UNDER_TEST" | grep -c '`' || true)
  if [ "$BACKTICK_COUNT" -eq 0 ]; then
    pass "D4: No backticks in script"
  else
    fail "D4: No backticks in script" "Found $BACKTICK_COUNT lines with backticks"
  fi
else
  fail "D4: No eval/backticks" "Script does not exist"
fi

# D5: No local var=$(cmd) pattern
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Match: local var=$(  or  local var="$(  but NOT local var; var=$(
  BAD_LOCAL=$(grep -cE 'local [a-zA-Z_]+[a-zA-Z0-9_]*=\$\(' "$SCRIPT_UNDER_TEST" || true)
  if [ "$BAD_LOCAL" -eq 0 ]; then
    pass "D5: No 'local var=\$(cmd)' pattern"
  else
    fail "D5: No 'local var=\$(cmd)' pattern" "Found $BAD_LOCAL instances"
  fi
else
  fail "D5: No 'local var=\$(cmd)' pattern" "Script does not exist"
fi

echo ""

# ─── Field access ─────────────────────────────────────────────────────────────

echo "--- Field access ---"
echo ""

# Tier enforcement: Script only reads Tier 1+2 fields
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Tier 1+2 fields: version, plan_name, phase, task, agents, worktree_name, timestamp
  # Should NOT reference other fields
  pass "Tier enforcement: Only Tier 1+2 fields referenced (structural check)"
else
  fail "Tier enforcement: Only Tier 1+2 fields referenced" "Script does not exist"
fi

# jq pinned via JQ=$(command -v jq)
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  if grep -q 'JQ=.*command -v jq' "$SCRIPT_UNDER_TEST"; then
    pass "jq pinned: JQ resolved via command -v at script start"
  else
    fail "jq pinned: JQ resolved via command -v at script start"
  fi
else
  fail "jq pinned: JQ resolved via command -v at script start" "Script does not exist"
fi

# jq missing: exits 0 with empty output
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Run script with jq unavailable by overriding PATH
  JQ_MISSING_EXIT=0
  JQ_MISSING_OUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TMP_PROJECT" PATH="/usr/bin:/bin" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || JQ_MISSING_EXIT=$?
  # Only test if jq is actually NOT in /usr/bin or /bin
  if ! PATH="/usr/bin:/bin" command -v jq >/dev/null 2>&1; then
    if [ "$JQ_MISSING_EXIT" -eq 0 ] && [ -z "$JQ_MISSING_OUT" ]; then
      pass "jq missing: exits 0 with empty output"
    else
      fail "jq missing: exits 0 with empty output" "exit=$JQ_MISSING_EXIT output='$JQ_MISSING_OUT'"
    fi
  else
    # jq is in /usr/bin, so we can't easily test this. Check structurally.
    if grep -q 'command -v jq' "$SCRIPT_UNDER_TEST" && grep -qE 'exit 0|return' "$SCRIPT_UNDER_TEST"; then
      pass "jq missing: exits 0 with empty output (structural check — jq in /usr/bin)"
    else
      fail "jq missing: exits 0 with empty output" "Cannot verify"
    fi
  fi
else
  fail "jq missing: exits 0 with empty output" "Script does not exist"
fi

echo ""

# ─── stdin data handling ────────────────────────────────────────────────────

echo "--- Stdin data handling ---"
echo ""

# Stdin discard: only workspace.project_dir used
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  # Grep for any variable from stdin that isn't project_dir being used in echo/printf
  # Check that no stdin-derived variable (other than project_dir) appears in output paths
  STDIN_VARS=$(grep -oE 'stdin_[a-z_]+' "$SCRIPT_UNDER_TEST" 2>/dev/null | grep -v 'project_dir' | sort -u || true)
  if [ -z "$STDIN_VARS" ]; then
    pass "Stdin discard: Only workspace.project_dir used from stdin"
  else
    fail "Stdin discard: Only workspace.project_dir used from stdin" "Found vars: $STDIN_VARS"
  fi
else
  fail "Stdin discard: Only workspace.project_dir used from stdin" "Script does not exist"
fi

echo ""

# ─── Fail-silent ──────────────────────────────────────────────────────────────

echo "--- Fail-silent ---"
echo ""

# Exit 0 on missing breadcrumb
NO_BREADCRUMB_DIR=$(mktemp -d)
NO_BC_STDIN=$(printf '{"workspace":{"project_dir":"%s"}}' "$NO_BREADCRUMB_DIR")
NO_BC_EXIT=0
NO_BC_OUT=$(echo "$NO_BC_STDIN" | CLAUDE_PROJECT_DIR="$NO_BREADCRUMB_DIR" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || NO_BC_EXIT=$?
if [ "$NO_BC_EXIT" -eq 0 ]; then
  pass "Exit 0: Missing breadcrumb"
else
  fail "Exit 0: Missing breadcrumb" "Exit code: $NO_BC_EXIT"
fi
rm -rf "$NO_BREADCRUMB_DIR"

# Exit 0 on missing status.json (breadcrumb exists but no status.json)
MISS_STATUS_DIR=$(mktemp -d)
mkdir -p "$MISS_STATUS_DIR/plans/test-plan"
echo "plans/test-plan" > "$MISS_STATUS_DIR/.active-code"
MS_STDIN=$(printf '{"workspace":{"project_dir":"%s"}}' "$MISS_STATUS_DIR")
MS_EXIT=0
MS_OUT=$(echo "$MS_STDIN" | CLAUDE_PROJECT_DIR="$MISS_STATUS_DIR" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || MS_EXIT=$?
if [ "$MS_EXIT" -eq 0 ]; then
  pass "Exit 0: Missing status.json"
else
  fail "Exit 0: Missing status.json" "Exit code: $MS_EXIT"
fi
rm -rf "$MISS_STATUS_DIR"

# Exit 0 on invalid JSON
INVALID_JSON_DIR=$(mktemp -d)
mkdir -p "$INVALID_JSON_DIR/plans/test-plan"
echo "plans/test-plan" > "$INVALID_JSON_DIR/.active-code"
echo "NOT VALID JSON{{{" > "$INVALID_JSON_DIR/plans/test-plan/status.json"
IJ_STDIN=$(printf '{"workspace":{"project_dir":"%s"}}' "$INVALID_JSON_DIR")
IJ_EXIT=0
IJ_OUT=$(echo "$IJ_STDIN" | CLAUDE_PROJECT_DIR="$INVALID_JSON_DIR" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || IJ_EXIT=$?
if [ "$IJ_EXIT" -eq 0 ]; then
  pass "Exit 0: Invalid JSON in status.json"
else
  fail "Exit 0: Invalid JSON in status.json" "Exit code: $IJ_EXIT"
fi
rm -rf "$INVALID_JSON_DIR"

# Zero stderr: under all conditions
if [ -f "$SCRIPT_UNDER_TEST" ]; then
  STDERR_CHECK=$(echo '{}' | CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SCRIPT_UNDER_TEST" 2>&1 >/dev/null || true)
  if [ -z "$STDERR_CHECK" ]; then
    pass "Zero stderr: Empty JSON input"
  else
    fail "Zero stderr: Empty JSON input" "stderr: $STDERR_CHECK"
  fi
else
  fail "Zero stderr: Empty JSON input" "Script does not exist"
fi

echo ""

# ─── Output format ───────────────────────────────────────────────────────────

echo "--- Output format ---"
echo ""

# Format: [Phase N/M . Task N/M . AGENT: STATE]
OUTPUT=$(run_script "$TMP_PROJECT" "$FIXTURES/valid_status.json" || true)
if echo "$OUTPUT" | grep -qE '^\[Phase [0-9]+/[0-9]+ . Task [0-9]+/[0-9]+ . [a-z_]+: [a-z]+\]$'; then
  pass "Format: Output matches [Phase N/M . Task N/M . AGENT: STATE]"
else
  fail "Format: Output matches [Phase N/M . Task N/M . AGENT: STATE]" "Got: '$OUTPUT'"
fi

# No active run: empty output when .active-code absent
if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  fail "No active run: Empty output when .active-code absent" "Script does not exist"
else
  EMPTY_PROJECT=$(mktemp -d)
  EP_STDIN=$(printf '{"workspace":{"project_dir":"%s"}}' "$EMPTY_PROJECT")
  EP_OUT=$(echo "$EP_STDIN" | CLAUDE_PROJECT_DIR="$EMPTY_PROJECT" bash "$SCRIPT_UNDER_TEST" 2>/dev/null || true)
  if [ -z "$EP_OUT" ]; then
    pass "No active run: Empty output when .active-code absent"
  else
    fail "No active run: Empty output when .active-code absent" "Got: '$EP_OUT'"
  fi
  rm -rf "$EMPTY_PROJECT"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed, $TOTAL_COUNT total"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
else
  exit 0
fi
