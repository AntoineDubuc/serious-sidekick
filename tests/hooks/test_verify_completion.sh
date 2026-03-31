#!/bin/bash
# test_verify_completion.sh — Task 3: Evidence file completeness + gate content validation
# Tests the hardened verify-completion-gate.sh hook.
#
# Usage: bash tests/hooks/test_verify_completion.sh
# Exit: 0 if all tests pass, 1 if any fail

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh"

run_test() {
  local name="$1"
  local expected_exit="$2"
  local actual_exit="$3"

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS: $name (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Task 3: Evidence File Completeness + Gate Content Validation ==="
echo ""

# --- Test 1: Complete evidence set (all 6 files with PASS in gate) → exit 0 ---
echo "Test 1: Complete evidence set with PASS verdict"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "ALL ACs PASS — 5/5 criteria met" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$SIM_ROOT/testdata/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$SIM_ROOT/testdata/evidence/task_01/review.md"
echo "# Test Evidence" > "$SIM_ROOT/testdata/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$SIM_ROOT/testdata/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$SIM_ROOT/testdata/evidence/task_01/qa.md"

echo "testdata" > "$SIM_ROOT/.active-code"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Complete evidence set (6 files + PASS verdict) allows exit" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Task with only gate_passed.md (missing 5 evidence files) → exit 2 ---
echo "Test 2: Task with only gate_passed.md (missing 5 evidence files)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "ALL ACs PASS" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
# Missing: implementation.md, review.md, tests.md, runtime.md, qa.md

echo "testdata" > "$SIM_ROOT/.active-code"
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Missing 5 evidence files blocks exit" 2 "$EXIT_CODE"

# Verify the error message lists specific missing files
if echo "$STDERR" | grep -q "EVIDENCE FILE BLOCK"; then
  echo "    (confirmed: EVIDENCE FILE BLOCK message present)"
else
  echo "    WARNING: Expected EVIDENCE FILE BLOCK in stderr"
fi
echo ""

# --- Test 3: gate_passed.md containing "FAIL" → exit 2 ---
echo "Test 3: gate_passed.md containing FAIL verdict"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "0/5 ACs passed — FAIL" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$SIM_ROOT/testdata/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$SIM_ROOT/testdata/evidence/task_01/review.md"
echo "# Test Evidence" > "$SIM_ROOT/testdata/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$SIM_ROOT/testdata/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$SIM_ROOT/testdata/evidence/task_01/qa.md"

echo "testdata" > "$SIM_ROOT/.active-code"
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
# The hook uses \bpass\b and \bfail\b word boundaries.
# "0/5 ACs passed — FAIL": \bpass\b does NOT match "passed", \bfail\b DOES match "FAIL".
# So HAS_FAIL > 0, which means the hook blocks (exit 2).
run_test "gate_passed.md with FAIL word blocks exit" 2 "$EXIT_CODE"
echo ""

# --- Test 3b: gate_passed.md with truly no PASS → exit 2 ---
echo "Test 3b: gate_passed.md with no PASS substring at all"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01"
echo "0/5 ACs met — REJECTED" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$SIM_ROOT/testdata/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$SIM_ROOT/testdata/evidence/task_01/review.md"
echo "# Test Evidence" > "$SIM_ROOT/testdata/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$SIM_ROOT/testdata/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$SIM_ROOT/testdata/evidence/task_01/qa.md"

echo "testdata" > "$SIM_ROOT/.active-code"
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "gate_passed.md with REJECTED (no PASS) blocks exit" 2 "$EXIT_CODE"

if echo "$STDERR" | grep -q "GATE VERDICT BLOCK"; then
  echo "    (confirmed: GATE VERDICT BLOCK message present)"
else
  echo "    WARNING: Expected GATE VERDICT BLOCK in stderr"
fi
echo ""

# --- Test 4: No evidence directory (early session) → exit 0 ---
echo "Test 4: No evidence directory (early session)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
# Don't create evidence directory at all

echo "testdata" > "$SIM_ROOT/.active-code"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "No evidence directory allows exit (early session)" 0 "$EXIT_CODE"
echo ""

# --- Test 5: No active session → exit 0 ---
echo "Test 5: No active session"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
# No .active-code breadcrumb
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "No .active-code breadcrumb allows exit" 0 "$EXIT_CODE"
echo ""

# --- Test 6: Multiple tasks, one incomplete → exit 2 ---
echo "Test 6: Two tasks, second missing evidence files"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata/evidence/task_01" "$SIM_ROOT/testdata/evidence/task_02"
# task_01 is complete
echo "ALL ACs PASS" > "$SIM_ROOT/testdata/evidence/task_01/gate_passed.md"
echo "# impl" > "$SIM_ROOT/testdata/evidence/task_01/implementation.md"
echo "# review" > "$SIM_ROOT/testdata/evidence/task_01/review.md"
echo "# tests" > "$SIM_ROOT/testdata/evidence/task_01/tests.md"
echo "# runtime" > "$SIM_ROOT/testdata/evidence/task_01/runtime.md"
echo "# qa" > "$SIM_ROOT/testdata/evidence/task_01/qa.md"
# task_02 has gate but missing evidence
echo "ALL ACs PASS" > "$SIM_ROOT/testdata/evidence/task_02/gate_passed.md"

echo "testdata" > "$SIM_ROOT/.active-code"
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Second task missing evidence files blocks exit" 2 "$EXIT_CODE"

if echo "$STDERR" | grep -q "task_02"; then
  echo "    (confirmed: task_02 mentioned in error)"
else
  echo "    WARNING: Expected task_02 in error output"
fi
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
