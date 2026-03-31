#!/bin/bash
# test_capture_research_ext.sh — Task 5: Extraction gate + verified stamp for capture-research.sh
#
# Tests:
#   1. Research done + source + _extracted_items.md + verified → exit 0
#   2. Research done + source + no _extracted_items.md → exit 2
#   3. Research done + no source → exit 0 (skip checks)
#   4. Research done + source + no verified stamp → exit 2
#
# Usage: bash tests/hooks/test_capture_research_ext.sh
# Exit: 0 if all pass, 1 if any fail

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/serious-research/hooks/capture-research.sh"

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

echo "=== Task 5: capture-research.sh — Extraction Gate + Verified Stamp ==="
echo ""

# --- Test 1: Full happy path ---
echo "Test 1: Research done + source + extracted + verified → exit 0"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/research.md" << 'RESEARCH'
---
skill: serious-research
slug: test
status: done
source: Research/conversations/test/summary.md
verified: 2026-03-29
---
# Research Findings
RESEARCH
echo "# Extracted Items" > "$SIM_ROOT/testdata/_extracted_items.md"

echo "testdata" > "$SIM_ROOT/.active-research"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Full happy path (done + source + extracted + verified)" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Research done + source + no _extracted_items.md ---
echo "Test 2: Research done + source + no _extracted_items.md → exit 2"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/research.md" << 'RESEARCH'
---
skill: serious-research
slug: test
status: done
source: Research/conversations/test/summary.md
verified: 2026-03-29
---
# Research Findings
RESEARCH
# Deliberately NOT creating _extracted_items.md

echo "testdata" > "$SIM_ROOT/.active-research"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Source without _extracted_items.md blocks" 2 "$EXIT_CODE"
echo ""

# --- Test 3: Research done + no source → exit 0 (skip checks) ---
echo "Test 3: Research done + no source → exit 0 (skip extraction checks)"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/research.md" << 'RESEARCH'
---
skill: serious-research
slug: test
status: done
---
# Research Findings
RESEARCH

echo "testdata" > "$SIM_ROOT/.active-research"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "No source skips extraction checks" 0 "$EXIT_CODE"
echo ""

# --- Test 4: Research done + source + no verified stamp ---
echo "Test 4: Research done + source + extracted + no verified stamp → exit 2"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/research.md" << 'RESEARCH'
---
skill: serious-research
slug: test
status: done
source: Research/conversations/test/summary.md
---
# Research Findings
RESEARCH
echo "# Extracted Items" > "$SIM_ROOT/testdata/_extracted_items.md"

echo "testdata" > "$SIM_ROOT/.active-research"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Source + extracted but no verified stamp blocks" 2 "$EXIT_CODE"
echo ""

# --- Summary ---
echo "=== RESULTS ==="
echo "Passed: $PASS / $((PASS + FAIL))"
echo "Failed: $FAIL / $((PASS + FAIL))"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "Some tests FAILED. Review output above."
  exit 1
fi
echo "All capture-research extension tests passed."
exit 0
