#!/bin/bash
# test_status_line.sh -- Tests for the /serious-code progress segment in statusline-command.sh
# Tests: output format, sanitization, fail-silent behavior, env var protection, shellcheck
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_UNDER_TEST="$HOME/.claude/statusline-command.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/status-line"

ERRORS=0
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert() {
  local desc="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc"
    [ -n "$detail" ] && echo "        $detail"
    ERRORS=$((ERRORS + 1))
  fi
}

# Helper: set up a temp project dir with breadcrumb + status.json
setup_project() {
  local tmp
  tmp=$(mktemp -d)
  local plan_dir="$tmp/plans/test-plan"
  mkdir -p "$plan_dir"
  echo "plans/test-plan" > "$tmp/.active-code"
  echo "$tmp"
}

# Helper: minimal stdin JSON for statusline-command.sh
# The script reads JSON from stdin; we provide minimal valid input
make_stdin() {
  local project_dir="${1:-/tmp/nonexistent}"
  printf '{"model":{"display_name":"Test"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":10}}' "$project_dir"
}

# Helper: run statusline-command.sh with a project dir and optional status.json
# Returns the SECOND line of output (the serious-code segment) if any
run_segment() {
  local project_dir="$1"
  local status_file="${2:-}"

  if [ -n "$status_file" ]; then
    local plan_dir="$project_dir/plans/test-plan"
    cp "$status_file" "$plan_dir/status.json" 2>/dev/null || true
  fi

  local output
  output=$(make_stdin "$project_dir" | CLAUDE_PROJECT_DIR="$project_dir" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || true
  # Return just the second line (the serious-code segment)
  echo "$output" | sed -n '2p'
}

# Helper: run and get ALL output
run_full() {
  local project_dir="$1"
  local status_file="${2:-}"

  if [ -n "$status_file" ]; then
    local plan_dir="$project_dir/plans/test-plan"
    cp "$status_file" "$plan_dir/status.json" 2>/dev/null || true
  fi

  make_stdin "$project_dir" | CLAUDE_PROJECT_DIR="$project_dir" bash "$SCRIPT_UNDER_TEST" 2>/dev/null || true
}

echo "=== Test: statusline-command.sh /serious-code segment ==="
echo ""

# ---- Pre-check: script exists ----
if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  echo "  FATAL: Script not found at $SCRIPT_UNDER_TEST"
  exit 1
fi

# ---- AC1: Valid status.json produces correct output format ----
echo "--- AC1: Valid status.json output format ---"

PROJECT1=$(setup_project)
SEGMENT=$(run_segment "$PROJECT1" "$FIXTURES/valid_status.json")

if echo "$SEGMENT" | grep -qE 'Phase [0-9]+/[0-9]+'; then
  assert "Valid status.json: output contains Phase N/N" "pass"
else
  assert "Valid status.json: output contains Phase N/N" "fail" "Got: '$SEGMENT'"
fi

if echo "$SEGMENT" | grep -qE 'Task [0-9]+/[0-9]+'; then
  assert "Valid status.json: output contains Task N/N" "pass"
else
  assert "Valid status.json: output contains Task N/N" "fail" "Got: '$SEGMENT'"
fi

if echo "$SEGMENT" | grep -q ':'; then
  assert "Valid status.json: output contains colon (agent: state)" "pass"
else
  assert "Valid status.json: output contains colon (agent: state)" "fail" "Got: '$SEGMENT'"
fi

if echo "$SEGMENT" | grep -q 'serious-code'; then
  assert "Valid status.json: output contains 'serious-code' label" "pass"
else
  assert "Valid status.json: output contains 'serious-code' label" "fail" "Got: '$SEGMENT'"
fi
rm -rf "$PROJECT1"

# ---- AC2: Empty JSON produces empty second line ----
echo "--- AC2: Empty JSON status.json ---"

PROJECT2=$(setup_project)
SEGMENT2=$(run_segment "$PROJECT2" "$FIXTURES/empty_status.json")

if [ -z "$SEGMENT2" ]; then
  assert "Empty status.json: no second line" "pass"
else
  assert "Empty status.json: no second line" "fail" "Got: '$SEGMENT2'"
fi
rm -rf "$PROJECT2"

# ---- AC3: Missing status.json produces empty second line ----
echo "--- AC3: Missing status.json ---"

PROJECT3=$(setup_project)
# Do NOT copy any status.json
SEGMENT3=$(run_segment "$PROJECT3")

if [ -z "$SEGMENT3" ]; then
  assert "Missing status.json: no second line" "pass"
else
  assert "Missing status.json: no second line" "fail" "Got: '$SEGMENT3'"
fi
rm -rf "$PROJECT3"

# ---- AC4: Malicious plan_name -- no ESC bytes in output ----
echo "--- AC4: Malicious plan_name sanitization ---"

PROJECT4=$(setup_project)
FULL4=$(run_full "$PROJECT4" "$FIXTURES/malicious_status.json")

# Check for ESC byte (0x1b) using LC_ALL=C and od
ESC_COUNT=$(printf '%s' "$FULL4" | LC_ALL=C tr -cd '\033' | wc -c | tr -d ' ')
# Subtract expected ANSI color codes -- the first line uses ANSI codes for colors
# We check the SECOND line only for unexpected ESC from the malicious payload
SEGMENT4=$(echo "$FULL4" | sed -n '2p')
# The second line has legitimate ANSI codes for formatting. We check that the
# plan_name portion doesn't inject extra ESC sequences.
# A more targeted check: strip known ANSI codes, then check for remaining ESC
STRIPPED=$(printf '%s' "$SEGMENT4" | sed $'s/\033\[[0-9;]*m//g')
REMAINING_ESC=$(printf '%s' "$STRIPPED" | LC_ALL=C tr -cd '\033' | wc -c | tr -d ' ')
if [ "$REMAINING_ESC" -eq 0 ]; then
  assert "Malicious plan_name: no raw ESC bytes after stripping ANSI colors" "pass"
else
  assert "Malicious plan_name: no raw ESC bytes after stripping ANSI colors" "fail" "Found $REMAINING_ESC ESC bytes"
fi
rm -rf "$PROJECT4"

# ---- AC5: Bidi override stripped ----
echo "--- AC5: Bidi override stripped ---"

PROJECT5=$(setup_project)
FULL5=$(run_full "$PROJECT5" "$FIXTURES/bidi_status.json")
# Check for U+202E (RLO) = 0xe2 0x80 0xae in the output
HAS_BIDI=$(printf '%s' "$FULL5" | LC_ALL=C grep -c $'\xe2\x80\xae' 2>/dev/null || true)
if [ "$HAS_BIDI" -eq 0 ]; then
  assert "Bidi override: no U+202E in output" "pass"
else
  assert "Bidi override: no U+202E in output" "fail" "Found bidi bytes in output"
fi
rm -rf "$PROJECT5"

# ---- AC6: Oversized field -- output length <= 4096 bytes ----
echo "--- AC6: Oversized field truncation ---"

PROJECT6=$(setup_project)
FULL6=$(run_full "$PROJECT6" "$FIXTURES/oversized_status.json")
FULL6_LEN=$(printf '%s' "$FULL6" | wc -c | tr -d ' ')
if [ "$FULL6_LEN" -le 4096 ]; then
  assert "Oversized plan_name: total output <= 4096 bytes (got $FULL6_LEN)" "pass"
else
  assert "Oversized plan_name: total output <= 4096 bytes" "fail" "Got $FULL6_LEN bytes"
fi
rm -rf "$PROJECT6"

# ---- AC7: Missing jq -- empty output, exit 0 ----
echo "--- AC7: Missing jq ---"

# We test structurally: the script should check for jq and exit 0 if missing
if grep -q 'command -v jq' "$SCRIPT_UNDER_TEST" || grep -q 'which jq' "$SCRIPT_UNDER_TEST"; then
  assert "Missing jq: script checks for jq availability" "pass"
else
  assert "Missing jq: script checks for jq availability" "fail" "No jq availability check found"
fi

# ---- AC8: Secret env vars not leaked ----
echo "--- AC8: Secret env vars not leaked ---"

PROJECT8=$(setup_project)
FULL8=$(ANTHROPIC_API_KEY="leaked_secret_key_12345" CLAUDE_PROJECT_DIR="$PROJECT8" make_stdin "$PROJECT8" | bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || true
if echo "$FULL8" | grep -q 'leaked_secret_key_12345'; then
  assert "Secret env vars: ANTHROPIC_API_KEY not leaked in output" "fail" "Found leaked key in output"
else
  assert "Secret env vars: ANTHROPIC_API_KEY not leaked in output" "pass"
fi
rm -rf "$PROJECT8"

# ---- AC9: Exit code is always 0 ----
echo "--- AC9: Exit code always 0 ---"

# Test with valid status
PROJECT9A=$(setup_project)
cp "$FIXTURES/valid_status.json" "$PROJECT9A/plans/test-plan/status.json"
EXIT9A=0
make_stdin "$PROJECT9A" | CLAUDE_PROJECT_DIR="$PROJECT9A" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>/dev/null || EXIT9A=$?
if [ "$EXIT9A" -eq 0 ]; then
  assert "Exit 0: with valid status.json" "pass"
else
  assert "Exit 0: with valid status.json" "fail" "Got exit $EXIT9A"
fi
rm -rf "$PROJECT9A"

# Test with no breadcrumb
PROJECT9B=$(mktemp -d)
EXIT9B=0
make_stdin "$PROJECT9B" | CLAUDE_PROJECT_DIR="$PROJECT9B" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>/dev/null || EXIT9B=$?
if [ "$EXIT9B" -eq 0 ]; then
  assert "Exit 0: no breadcrumb" "pass"
else
  assert "Exit 0: no breadcrumb" "fail" "Got exit $EXIT9B"
fi
rm -rf "$PROJECT9B"

# Test with malicious data
PROJECT9C=$(setup_project)
cp "$FIXTURES/malicious_status.json" "$PROJECT9C/plans/test-plan/status.json"
EXIT9C=0
make_stdin "$PROJECT9C" | CLAUDE_PROJECT_DIR="$PROJECT9C" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>/dev/null || EXIT9C=$?
if [ "$EXIT9C" -eq 0 ]; then
  assert "Exit 0: with malicious status.json" "pass"
else
  assert "Exit 0: with malicious status.json" "fail" "Got exit $EXIT9C"
fi
rm -rf "$PROJECT9C"

# ---- AC10: All agents idle shows "idle" ----
echo "--- AC10: All agents idle shows idle ---"

# Create a status.json where all agents are idle
ALL_IDLE_JSON="$TMP_DIR/all_idle.json"
cat > "$ALL_IDLE_JSON" << 'HEREDOC'
{"version":1,"plan_name":"test-plan","phase":{"current":1,"total":2},"task":{"current":1,"total":3},"agents":{"implementer":"idle","reviewer":"idle","test_runner":"idle","runtime_checker":"idle","qa":"idle"},"worktree_name":"","timestamp":"2026-04-12T10:30:00Z"}
HEREDOC

PROJECT10=$(setup_project)
SEGMENT10=$(run_segment "$PROJECT10" "$ALL_IDLE_JSON")
if echo "$SEGMENT10" | grep -qi 'idle'; then
  assert "All agents idle: output shows 'idle'" "pass"
else
  assert "All agents idle: output shows 'idle'" "fail" "Got: '$SEGMENT10'"
fi
rm -rf "$PROJECT10"

# ---- AC11: shellcheck passes ----
echo "--- AC11: shellcheck ---"

if command -v shellcheck >/dev/null 2>&1; then
  SC_OUTPUT=$(shellcheck --severity=error "$SCRIPT_UNDER_TEST" 2>&1 || true)
  SC_EXIT=$?
  if [ -z "$SC_OUTPUT" ] || [ "$SC_EXIT" -eq 0 ]; then
    assert "shellcheck --severity=error passes on statusline-command.sh" "pass"
  else
    assert "shellcheck --severity=error passes on statusline-command.sh" "fail" "Findings: $SC_OUTPUT"
  fi
else
  assert "shellcheck --severity=error passes on statusline-command.sh" "fail" "shellcheck not installed"
fi

# ---- AC12: First line unchanged when no active run ----
echo "--- AC12: First line unchanged when no /serious-code run ---"

PROJECT12=$(mktemp -d)
# No .active-code breadcrumb -- should produce exactly 1 line
FULL12=$(make_stdin "$PROJECT12" | CLAUDE_PROJECT_DIR="$PROJECT12" bash "$SCRIPT_UNDER_TEST" 2>/dev/null) || true
LINE_COUNT12=$(echo "$FULL12" | wc -l | tr -d ' ')
if [ "$LINE_COUNT12" -eq 1 ]; then
  assert "No active run: exactly 1 line of output" "pass"
else
  assert "No active run: exactly 1 line of output" "fail" "Got $LINE_COUNT12 lines"
fi
rm -rf "$PROJECT12"

# ---- AC13: Secret env vars unset at top of script ----
echo "--- AC13: Secret env vars unset ---"

if grep -q 'unset ANTHROPIC_API_KEY' "$SCRIPT_UNDER_TEST"; then
  assert "unset ANTHROPIC_API_KEY present in script" "pass"
else
  assert "unset ANTHROPIC_API_KEY present in script" "fail"
fi

if grep -q 'unset.*OPENAI_API_KEY\|OPENAI_API_KEY' "$SCRIPT_UNDER_TEST" && grep -q 'unset' "$SCRIPT_UNDER_TEST"; then
  assert "unset covers multiple secret env vars" "pass"
else
  assert "unset covers multiple secret env vars" "fail"
fi

echo ""
echo "Status-line test errors: $ERRORS"
[ "$ERRORS" -eq 0 ] || exit 1
