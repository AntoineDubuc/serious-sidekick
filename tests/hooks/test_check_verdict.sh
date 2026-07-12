#!/bin/bash
# test_check_verdict.sh — Task 2: Agent dispatch validation in check-verdict.sh
# Tests that review_verdict.md must contain all 5 mandatory agent sections
# (anti-slop, structural, security, restraint, code-aware correctness).
#
# Usage: bash tests/hooks/test_check_verdict.sh
# Exit: 0 if all tests pass, 1 if any fail

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/serious-review/hooks/check-verdict.sh"

run_test() {
  local name="$1"
  local expected_exit="$2"
  local actual_exit="$3"

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS: $name (exit $actual_exit as expected)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Task 2: Agent Dispatch Validation — check-verdict.sh ==="
echo ""

# --- Test 1: Verdict with all 5 sections → exit 0 ---
echo "Test 1: Verdict with all 5 mandatory agent sections"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict

**Verdict:** PASS

## Anti-Slop Audit Report

### Check 1: Weasel Word Scan — PASS
Found: src/main.ts:42 uses clear language.
Reference: implementation_plan.md:15 avoids vague terms.

## Structural Review Report

### Completeness — PASS
All tasks reference: src/auth.ts:10 and config.yaml:3
Cross-checked: implementation_plan.md:22 against research.md:8

## Security Review Report

### Input Validation — PASS
Verified: src/api.ts:55 validates all inputs.
Reference: implementation_plan.md:30 includes sanitization steps.

## Restraint Review Report

### Reuse check — LEAN
Reuse verified: src/util.ts:12 already provides this; no reinvention.

## Code-Aware Correctness Review

### Mechanism — PASS
Fix covers all paths: src/handler.ts:88 and src/handler.ts:120.
VERDICT

echo "testdata" > "$SIM_ROOT/.active-review"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "All 5 agent sections present → exit 0" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Verdict with only Anti-Slop → exit 2 (missing structural + security) ---
echo "Test 2: Verdict with only Anti-Slop section (missing 2 agents)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict

**Verdict:** PASS

## Anti-Slop Audit Report

### Check 1: Weasel Word Scan — PASS
Found: src/main.ts:42 uses clear language.
Reference: implementation_plan.md:15 avoids vague terms.
VERDICT

echo "testdata" > "$SIM_ROOT/.active-review"
OUTPUT=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Only Anti-Slop section → exit 2" 2 "$EXIT_CODE"
# Verify the error message lists the correct missing agents
if echo "$OUTPUT" | grep -q "Structural Reviewer" && echo "$OUTPUT" | grep -q "Security Mind"; then
  echo "  PASS: Error message lists both missing agents"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error message should list Structural Reviewer and Security Mind"
  echo "  Got: $OUTPUT"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Test 3: Verdict with no agent sections → exit 2 (missing all 3) ---
echo "Test 3: Verdict with no agent sections (missing all 3)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict

**Verdict:** PASS

Everything looks good. The plan is solid.
Reference: implementation_plan.md:1 is a file reference so Layer 2 won't trigger.
VERDICT

echo "testdata" > "$SIM_ROOT/.active-review"
OUTPUT=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "No agent sections → exit 2" 2 "$EXIT_CODE"
# Verify all 3 missing agents are listed
if echo "$OUTPUT" | grep -q "Anti-Slop Auditor" && \
   echo "$OUTPUT" | grep -q "Structural Reviewer" && \
   echo "$OUTPUT" | grep -q "Security Mind"; then
  echo "  PASS: Error message lists all 3 missing agents"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error message should list all 3 missing agents"
  echo "  Got: $OUTPUT"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Test 4: All 5 sections but no file:line refs → exit 2 (Layer 2 review theater) ---
echo "Test 4: All 5 sections but PASS with zero file:line refs (Layer 2 triggers)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict

**Verdict:** PASS

## Anti-Slop Audit Report

### Check 1: Weasel Word Scan — PASS
Everything looks great, no issues found.

## Structural Review Report

### Completeness — PASS
All tasks are well structured and complete.

## Security Review Report

### Input Validation — PASS
Security looks good across the board.

## Restraint Review Report

### Reuse check — LEAN
Nothing to cut, looks minimal.

## Code-Aware Correctness Review

### Mechanism — PASS
The fix looks correct and complete.
VERDICT

echo "testdata" > "$SIM_ROOT/.active-review"
OUTPUT=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "All sections but no file:line refs → exit 2 (review theater)" 2 "$EXIT_CODE"
# Verify it's the Layer 2 check that triggers, not Layer 3
if echo "$OUTPUT" | grep -q "REVIEW QUALITY WARNING"; then
  echo "  PASS: Layer 2 (review theater) check caught it, not Layer 3"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Expected REVIEW QUALITY WARNING from Layer 2"
  echo "  Got: $OUTPUT"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Test 5: Old 3-section verdict (no restraint/correctness) → exit 2 ---
echo "Test 5: Only the original 3 sections (missing restraint + correctness)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/review_verdict.md" << 'VERDICT'
---
skill: serious-review
slug: test
status: done
---
# Review Verdict

**Verdict:** PASS

## Anti-Slop Audit Report

### Check 1 — PASS
Reference: implementation_plan.md:15 is concrete.

## Structural Review Report

### Completeness — PASS
Cross-checked: implementation_plan.md:22 against research.md:8

## Security Review Report

### Input Validation — PASS
Verified: src/api.ts:55 validates inputs.
VERDICT

echo "testdata" > "$SIM_ROOT/.active-review"
OUTPUT=$(bash "$HOOK" 2>&1)
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Missing restraint + correctness → exit 2" 2 "$EXIT_CODE"
if echo "$OUTPUT" | grep -q "Restraint Reviewer" && echo "$OUTPUT" | grep -q "Code-Aware Correctness Reviewer"; then
  echo "  PASS: Error message lists the two new missing reviewers"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error message should list Restraint Reviewer and Code-Aware Correctness Reviewer"
  echo "  Got: $OUTPUT"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "Some tests failed. Review output above."
  exit 1
fi
echo "All agent dispatch validation tests passed."
exit 0
