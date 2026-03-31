#!/bin/bash
# test_worktree_simulation.sh — Worktree breadcrumb path fix regression tests
# Verifies hooks find breadcrumbs when CWD != CLAUDE_PROJECT_DIR (worktree scenario).
#
# Usage: bash tests/hooks/test_worktree_simulation.sh
# Exit: 0 if all tests pass, 1 if any fail

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

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

cleanup() {
  rm -rf "$SIM_ROOT" "$WORKTREE_SIM" 2>/dev/null
}
trap cleanup EXIT ERR

echo "=== Worktree Simulation Tests ==="
echo "Verifies hooks work when CWD is different from CLAUDE_PROJECT_DIR"
echo ""

# --- Test 1: Stop hook finds breadcrumb from worktree CWD ---
echo "Test 1: verify-completion-gate.sh finds breadcrumb from worktree CWD"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
mkdir -p "$SIM_ROOT/testdata"
echo "testdata" > "$SIM_ROOT/.active-code"
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Stop hook finds breadcrumb from worktree CWD (no evidence dir -> exit 0)" 0 "$EXIT_CODE"
cleanup
echo ""

# --- Test 2: PreToolUse hook finds breadcrumb from worktree CWD ---
echo "Test 2: tdd-gate.sh finds breadcrumb from worktree CWD"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
echo "testdata" > "$SIM_ROOT/.active-code"
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/tdd-gate.sh" 2>/dev/null
EXIT_CODE=$?
run_test "PreToolUse hook finds breadcrumb from worktree CWD (no tool input -> exit 0)" 0 "$EXIT_CODE"
cleanup
echo ""

# --- Test 3: Stop hook reads breadcrumb content and resolves artifact directory ---
echo "Test 3: check-verdict.sh reads breadcrumb content and blocks (no verdict)"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
mkdir -p "$SIM_ROOT/testdata"
echo "testdata" > "$SIM_ROOT/.active-review"
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Stop hook reads content, resolves dir, blocks without verdict (exit 2)" 2 "$EXIT_CODE"
cleanup
echo ""

# --- Test 4: Stop hook with full artifacts passes from worktree CWD ---
echo "Test 4: check-verdict.sh passes when verdict exists (from worktree CWD)"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
mkdir -p "$SIM_ROOT/testdata"
echo "testdata" > "$SIM_ROOT/.active-review"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
Verdict: PASS

## Anti-Slop Audit Report
check-verdict.sh:39 - extension list expanded

## Structural Review Report
implementation_plan.md:177 - dashboard consistent

## Security Review Report
implementation_plan.md:326 - path validation added
VERDICT
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Stop hook passes with valid verdict from worktree CWD (exit 0)" 0 "$EXIT_CODE"
cleanup
echo ""

# --- Test 5: Fallback to CWD when CLAUDE_PROJECT_DIR is unset ---
echo "Test 5: Fallback to CWD when CLAUDE_PROJECT_DIR is unset"
SIM_ROOT=$(mktemp -d)
mkdir -p "$SIM_ROOT/testdata"
echo "testdata" > "$SIM_ROOT/.active-review"
cd "$SIM_ROOT"
unset CLAUDE_PROJECT_DIR
bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Fallback to CWD (exit 2 — breadcrumb found at CWD, no verdict)" 2 "$EXIT_CODE"
export CLAUDE_PROJECT_DIR="$PROJECT_ROOT"
cleanup
echo ""

# --- Test 6: No breadcrumb at SIM_ROOT → exit 0 ---
echo "Test 6: No breadcrumb → exit 0 (no active session)"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
# No breadcrumb written
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
EXIT_CODE=$?
run_test "No breadcrumb at PROJECT_ROOT → exit 0" 0 "$EXIT_CODE"
cleanup
echo ""

# --- Test 7: Breadcrumb ONLY at worktree CWD (wrong place) → exit 0 ---
echo "Test 7: Breadcrumb at worktree CWD (wrong place) → exit 0"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
echo "testdata" > "$WORKTREE_SIM/.active-review"  # Wrong place!
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Breadcrumb at CWD not PROJECT_ROOT → exit 0 (correctly ignored)" 0 "$EXIT_CODE"
cleanup
echo ""

# --- Test 8: Path traversal in breadcrumb content → rejected ---
echo "Test 8: Path traversal in breadcrumb content → rejected"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
echo "../../etc/passwd" > "$SIM_ROOT/.active-code"
cd "$WORKTREE_SIM"
OUTPUT=$(CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>&1)
EXIT_CODE=$?
run_test "Path traversal rejected (exit 0)" 0 "$EXIT_CODE"
echo "$OUTPUT" | grep -q "WARNING: breadcrumb content rejected"
run_test "Warning message produced for traversal" 0 $?
cleanup
echo ""

# --- Test 9: Absolute path in breadcrumb content → rejected ---
echo "Test 9: Absolute path in breadcrumb content → rejected"
SIM_ROOT=$(mktemp -d)
WORKTREE_SIM=$(mktemp -d)
echo "/tmp/evil" > "$SIM_ROOT/.active-code"
cd "$WORKTREE_SIM"
OUTPUT=$(CLAUDE_PROJECT_DIR="$SIM_ROOT" bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>&1)
EXIT_CODE=$?
run_test "Absolute path rejected (exit 0)" 0 "$EXIT_CODE"
echo "$OUTPUT" | grep -q "WARNING: breadcrumb content rejected"
run_test "Warning message produced for absolute path" 0 $?
cleanup
echo ""

# --- Test 10: PROJECT_ROOT doesn't exist → exit 0 ---
echo "Test 10: Non-existent PROJECT_ROOT → exit 0"
WORKTREE_SIM=$(mktemp -d)
cd "$WORKTREE_SIM"
CLAUDE_PROJECT_DIR="/nonexistent/path" bash "$PROJECT_ROOT/.claude/skills/serious-code/hooks/verify-completion-gate.sh" 2>/dev/null
EXIT_CODE=$?
run_test "Non-existent PROJECT_ROOT → exit 0" 0 "$EXIT_CODE"
rm -rf "$WORKTREE_SIM"
echo ""

# --- Results ---
cd "$PROJECT_ROOT"
export CLAUDE_PROJECT_DIR="$PROJECT_ROOT"
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "Some worktree simulation tests FAILED."
  exit 1
else
  echo "All worktree simulation tests passed."
fi
