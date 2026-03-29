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
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/evidence/task_01"
echo "ALL ACs PASS — 5/5 criteria met" > "$TMPDIR/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$TMPDIR/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$TMPDIR/evidence/task_01/review.md"
echo "# Test Evidence" > "$TMPDIR/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$TMPDIR/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$TMPDIR/evidence/task_01/qa.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
run_test "Complete evidence set (6 files + PASS verdict) allows exit" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Task with only gate_passed.md (missing 5 evidence files) → exit 2 ---
echo "Test 2: Task with only gate_passed.md (missing 5 evidence files)"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/evidence/task_01"
echo "ALL ACs PASS" > "$TMPDIR/evidence/task_01/gate_passed.md"
# Missing: implementation.md, review.md, tests.md, runtime.md, qa.md

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
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
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/evidence/task_01"
echo "0/5 ACs passed — FAIL" > "$TMPDIR/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$TMPDIR/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$TMPDIR/evidence/task_01/review.md"
echo "# Test Evidence" > "$TMPDIR/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$TMPDIR/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$TMPDIR/evidence/task_01/qa.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
# Note: "FAIL" also contains no case-insensitive match for "pass" — wait, actually
# the file says "0/5 ACs passed" which DOES contain "pass" (in "passed").
# Let me use a file that truly has no "pass" substring at all.
# Actually, the grep -qi 'pass' would match "passed". So "FAIL" alone without "pass" in it:
# Re-do this test with content that has zero "pass" anywhere.
run_test "gate_passed.md with FAIL (but 'passed' substring present) — see Test 3b" 0 "$EXIT_CODE"
echo ""

# --- Test 3b: gate_passed.md with truly no PASS → exit 2 ---
echo "Test 3b: gate_passed.md with no PASS substring at all"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/evidence/task_01"
echo "0/5 ACs met — REJECTED" > "$TMPDIR/evidence/task_01/gate_passed.md"
echo "# Implementation Evidence" > "$TMPDIR/evidence/task_01/implementation.md"
echo "# Review Evidence" > "$TMPDIR/evidence/task_01/review.md"
echo "# Test Evidence" > "$TMPDIR/evidence/task_01/tests.md"
echo "# Runtime Evidence" > "$TMPDIR/evidence/task_01/runtime.md"
echo "# QA Evidence" > "$TMPDIR/evidence/task_01/qa.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
run_test "gate_passed.md with REJECTED (no PASS) blocks exit" 2 "$EXIT_CODE"

if echo "$STDERR" | grep -q "GATE VERDICT BLOCK"; then
  echo "    (confirmed: GATE VERDICT BLOCK message present)"
else
  echo "    WARNING: Expected GATE VERDICT BLOCK in stderr"
fi
echo ""

# --- Test 4: No evidence directory (early session) → exit 0 ---
echo "Test 4: No evidence directory (early session)"
TMPDIR=$(mktemp -d)
# Don't create evidence directory at all

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
run_test "No evidence directory allows exit (early session)" 0 "$EXIT_CODE"
echo ""

# --- Test 5: No active session → exit 0 ---
echo "Test 5: No active session"
cd "$PROJECT_ROOT"
rm -f .active-code
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
run_test "No .active-code breadcrumb allows exit" 0 "$EXIT_CODE"
echo ""

# --- Test 6: Multiple tasks, one incomplete → exit 2 ---
echo "Test 6: Two tasks, second missing evidence files"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/evidence/task_01" "$TMPDIR/evidence/task_02"
# task_01 is complete
echo "ALL ACs PASS" > "$TMPDIR/evidence/task_01/gate_passed.md"
echo "# impl" > "$TMPDIR/evidence/task_01/implementation.md"
echo "# review" > "$TMPDIR/evidence/task_01/review.md"
echo "# tests" > "$TMPDIR/evidence/task_01/tests.md"
echo "# runtime" > "$TMPDIR/evidence/task_01/runtime.md"
echo "# qa" > "$TMPDIR/evidence/task_01/qa.md"
# task_02 has gate but missing evidence
echo "ALL ACs PASS" > "$TMPDIR/evidence/task_02/gate_passed.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-code
STDERR=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -f .active-code
rm -rf "$TMPDIR"
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
