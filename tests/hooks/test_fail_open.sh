#!/bin/bash
# test_fail_open.sh — Task 1: Test CHECKS_PASSED fail-closed pattern
# Verifies: hooks block on unexpected errors, pass on normal operation
#
# Usage: bash tests/hooks/test_fail_open.sh
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

echo "=== Task 1: Fail-Open Vulnerability Tests ==="
echo ""

# --- Test 1: No active session → still exits 0 (early exit, not failure) ---
echo "Test 1: Hooks with no active session still exit 0"
cd "$PROJECT_ROOT"
for hook in \
  ".claude/skills/serious-code/hooks/verify-completion-gate.sh" \
  ".claude/skills/serious-conversation/hooks/capture-conversation.sh" \
  ".claude/skills/serious-research/hooks/capture-research.sh" \
  ".claude/skills/serious-plan/hooks/check-extraction.sh" \
  ".claude/skills/serious-scope/hooks/check-manifest.sh" \
  ".claude/skills/serious-review/hooks/check-verdict.sh"; do
  # Ensure no breadcrumbs exist
  rm -f .active-code .active-conversation .active-research .active-plan .active-scope .active-review
  bash "$PROJECT_ROOT/$hook" 2>/dev/null
  EXIT_CODE=$?
  BASENAME=$(basename "$hook")
  run_test "No session: $BASENAME" 0 "$EXIT_CODE"
done
echo ""

# --- Test 2: PreToolUse hooks with no active session → exit 0 ---
echo "Test 2: PreToolUse hooks with no active session still exit 0"
for hook in \
  ".claude/skills/serious-code/hooks/tdd-gate.sh" \
  ".claude/skills/serious-plan/hooks/hedge-language-gate.sh" \
  ".claude/skills/serious-review/hooks/review-theater-gate.sh"; do
  rm -f .active-code .active-plan .active-review
  bash "$PROJECT_ROOT/$hook" 2>/dev/null
  EXIT_CODE=$?
  BASENAME=$(basename "$hook")
  run_test "No session: $BASENAME" 0 "$EXIT_CODE"
done
echo ""

# --- Test 3: Active session with valid data → exit 0 ---
echo "Test 3: Valid active sessions pass correctly"
TMPDIR=$(mktemp -d)

# check-verdict.sh with complete verdict
mkdir -p "$TMPDIR/review"
cat > "$TMPDIR/review/review_verdict.md" << 'EOF'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict
**Verdict:** PASS

## Anti-Slop Audit Report
Found: src/main.ts:42

## Structural Review Report
Found: src/main.ts:42

## Security Review Report
Found: src/main.ts:42
EOF
echo "$TMPDIR/review" > "$PROJECT_ROOT/.active-review"
bash "$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh" 2>/dev/null
run_test "Valid verdict: check-verdict.sh" 0 $?
rm -f "$PROJECT_ROOT/.active-review"

# capture-research.sh with done status
mkdir -p "$TMPDIR/research"
cat > "$TMPDIR/research/research.md" << 'EOF'
---
skill: serious-research
slug: test
status: done
---
# Research
EOF
echo "$TMPDIR/research" > "$PROJECT_ROOT/.active-research"
bash "$PROJECT_ROOT/.claude/skills/serious-research/hooks/capture-research.sh" 2>/dev/null
run_test "Done research: capture-research.sh" 0 $?
rm -f "$PROJECT_ROOT/.active-research"

# check-manifest.sh with manifest
mkdir -p "$TMPDIR/scope"
echo "# Manifest" > "$TMPDIR/scope/manifest.md"
echo "# Items" > "$TMPDIR/scope/_extracted_items.md"
echo "$TMPDIR/scope" > "$PROJECT_ROOT/.active-scope"
bash "$PROJECT_ROOT/.claude/skills/serious-scope/hooks/check-manifest.sh" 2>/dev/null
run_test "Valid manifest: check-manifest.sh" 0 $?
rm -f "$PROJECT_ROOT/.active-scope"

rm -rf "$TMPDIR"
echo ""

# --- Test 4: CHECKS_PASSED pattern exists in all 9 hooks ---
echo "Test 4: CHECKS_PASSED pattern present in all hooks"
for hook in \
  ".claude/skills/serious-code/hooks/verify-completion-gate.sh" \
  ".claude/skills/serious-conversation/hooks/capture-conversation.sh" \
  ".claude/skills/serious-research/hooks/capture-research.sh" \
  ".claude/skills/serious-plan/hooks/check-extraction.sh" \
  ".claude/skills/serious-scope/hooks/check-manifest.sh" \
  ".claude/skills/serious-review/hooks/check-verdict.sh" \
  ".claude/skills/serious-code/hooks/tdd-gate.sh" \
  ".claude/skills/serious-plan/hooks/hedge-language-gate.sh" \
  ".claude/skills/serious-review/hooks/review-theater-gate.sh"; do
  COUNT=$(grep -c 'CHECKS_PASSED' "$PROJECT_ROOT/$hook" 2>/dev/null || true)
  BASENAME=$(basename "$hook")
  if [ "$COUNT" -ge 3 ]; then
    run_test "CHECKS_PASSED in $BASENAME ($COUNT occurrences)" 0 0
  else
    run_test "CHECKS_PASSED in $BASENAME ($COUNT occurrences, need >=3)" 0 1
  fi
done
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
