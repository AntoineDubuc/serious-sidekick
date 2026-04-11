#!/bin/bash
# stop-hook-guard.test.sh — Unit tests for stop-hook-guard.sh
# Run: bash ~/.claude/skills/_shared/stop-hook-guard.test.sh
#
# Each test runs the function in a subshell so exit calls don't kill the runner.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD_SCRIPT="${SCRIPT_DIR}/stop-hook-guard.sh"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $1"; }

# Helper: source the guard with controlled stdin, then call a function.
# Usage: run_guard "stdin_content" "function_name" [args...]
# Returns the exit code of the function.
run_guard() {
  local stdin_content="$1"
  shift
  local func="$1"
  shift
  echo "$stdin_content" | bash -c "
    source '${GUARD_SCRIPT}'
    $func \"\$@\"
  " -- "$@"
  return $?
}

echo "=== guard_stop_hook_active ==="

test_guard_stop_hook_active_true_exits_0() {
  run_guard '{"stop_hook_active":true}' guard_stop_hook_active > /dev/null 2>&1
  if [ $? -eq 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_stop_hook_active_false_continues() {
  # When stop_hook_active=false, the function should return (not exit).
  # We append an "echo survived" after the call to prove it returned.
  local output
  output=$(echo '{"stop_hook_active":false}' | bash -c "
    source '${GUARD_SCRIPT}'
    guard_stop_hook_active
    echo survived
  " 2>/dev/null)
  if echo "$output" | grep -q "survived"; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_stop_hook_active_empty_stdin_continues() {
  # Empty stdin: guard returns (doesn't exit), so "survived" should print.
  local output
  output=$(echo '' | bash -c "
    source '${GUARD_SCRIPT}'
    guard_stop_hook_active
    echo survived
  " 2>/dev/null)
  if echo "$output" | grep -q "survived"; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_stop_hook_active_malformed_json_continues() {
  local output
  output=$(echo 'not-json-at-all' | bash -c "
    source '${GUARD_SCRIPT}'
    guard_stop_hook_active
    echo survived
  " 2>/dev/null)
  if echo "$output" | grep -q "survived"; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_stop_hook_active_missing_field_continues() {
  local output
  output=$(echo '{"other_field":"value"}' | bash -c "
    source '${GUARD_SCRIPT}'
    guard_stop_hook_active
    echo survived
  " 2>/dev/null)
  if echo "$output" | grep -q "survived"; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

echo ""
echo "=== guard_terminal_state ==="

test_guard_terminal_state_marker_present_continues() {
  local tmpfile
  tmpfile=$(mktemp)
  printf -- '---\nstatus: done\n---\n' > "$tmpfile"
  local output
  output=$(echo '{}' | bash -c "
    source '${GUARD_SCRIPT}'
    guard_terminal_state '$tmpfile' 'status: done'
    echo survived
  " 2>/dev/null)
  rm -f "$tmpfile"
  if echo "$output" | grep -q "survived"; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_terminal_state_marker_absent_exits_0() {
  local tmpfile
  tmpfile=$(mktemp)
  printf -- '---\nstatus: active\n---\n' > "$tmpfile"
  run_guard '{}' guard_terminal_state "$tmpfile" "status: done" > /dev/null 2>&1
  local code=$?
  rm -f "$tmpfile"
  if [ $code -eq 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_terminal_state_missing_file_exits_0() {
  run_guard '{}' guard_terminal_state "/nonexistent/path" "status: done" > /dev/null 2>&1
  if [ $? -eq 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_guard_terminal_state_empty_marker_exits_0() {
  local tmpfile
  tmpfile=$(mktemp)
  echo "content" > "$tmpfile"
  run_guard '{}' guard_terminal_state "$tmpfile" "" > /dev/null 2>&1
  local code=$?
  rm -f "$tmpfile"
  if [ $code -eq 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

echo ""
echo "=== emit_advisory_then_exit_0 ==="

test_emit_advisory_prints_to_stderr_and_exits_0() {
  local stderr_output
  stderr_output=$(run_guard '{}' emit_advisory_then_exit_0 "Advisory message here" 2>&1 1>/dev/null)
  local code=$?
  if [ $code -eq 0 ] && echo "$stderr_output" | grep -q "Advisory message here"; then pass "$FUNCNAME"; else fail "$FUNCNAME (code=$code, stderr=$stderr_output)"; fi
}

test_emit_advisory_empty_message_exits_0() {
  run_guard '{}' emit_advisory_then_exit_0 "" > /dev/null 2>&1
  if [ $? -eq 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_emit_advisory_never_exits_2() {
  run_guard '{}' emit_advisory_then_exit_0 "test" > /dev/null 2>&1
  if [ $? -ne 2 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

echo ""
echo "=== emit_block_then_exit_2 ==="

test_emit_block_prints_to_stderr_and_exits_2() {
  local stderr_output
  stderr_output=$(run_guard '{}' emit_block_then_exit_2 "Block reason here" 2>&1 1>/dev/null)
  local code=$?
  if [ $code -eq 2 ] && echo "$stderr_output" | grep -q "Block reason here"; then pass "$FUNCNAME"; else fail "$FUNCNAME (code=$code, stderr=$stderr_output)"; fi
}

test_emit_block_empty_message_exits_2() {
  run_guard '{}' emit_block_then_exit_2 "" > /dev/null 2>&1
  if [ $? -eq 2 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

test_emit_block_never_exits_0() {
  run_guard '{}' emit_block_then_exit_2 "test" > /dev/null 2>&1
  if [ $? -ne 0 ]; then pass "$FUNCNAME"; else fail "$FUNCNAME"; fi
}

# --- Run all tests ---
test_guard_stop_hook_active_true_exits_0
test_guard_stop_hook_active_false_continues
test_guard_stop_hook_active_empty_stdin_continues
test_guard_stop_hook_active_malformed_json_continues
test_guard_stop_hook_active_missing_field_continues
test_guard_terminal_state_marker_present_continues
test_guard_terminal_state_marker_absent_exits_0
test_guard_terminal_state_missing_file_exits_0
test_guard_terminal_state_empty_marker_exits_0
test_emit_advisory_prints_to_stderr_and_exits_0
test_emit_advisory_empty_message_exits_0
test_emit_advisory_never_exits_2
test_emit_block_prints_to_stderr_and_exits_2
test_emit_block_empty_message_exits_2
test_emit_block_never_exits_0

echo ""
echo "=== Results ==="
echo "Passed: ${PASS_COUNT}/${TOTAL}"
echo "Failed: ${FAIL_COUNT}/${TOTAL}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
