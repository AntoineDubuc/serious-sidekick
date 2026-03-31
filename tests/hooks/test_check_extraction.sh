#!/bin/bash
# test_check_extraction.sh — Task 4: Citation counting + verified stamp checks
# Tests the two new blocks added to check-extraction.sh:
#   Block A: Citation cross-reference (items present vs [Source:] citations)
#   Block B: Handoff verifier stamp (source present vs verified: stamp)
#
# Usage: bash tests/hooks/test_check_extraction.sh
# Exit: 0 if all tests pass, 1 if any test fails

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${PROJECT_ROOT}/.claude/skills/serious-plan/hooks/check-extraction.sh"

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

echo "=== Task 4: check-extraction.sh — Citation Counting + Verified Stamp ==="
echo ""

# ============================================================
# Test 1: Items present + citations present + verified stamp -> exit 0
# ============================================================
echo "--- Test 1: Full pass — items, citations, verified stamp ---"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"

echo "testdata" > "$SIM_ROOT/.active-plan"

# Plan with source, verified stamp, citations, and clean task section
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test-plan
status: active
source: Research/features/test/research.md
verified: 2026-03-29
---

## Acceptance Criteria
- Widget renders correctly [Source: research.md #1]
- API returns 200 [Source: research.md #2]

## Task Descriptions
### Task 1: Implement widget
Create the widget component at src/Widget.tsx.
PLAN

# Extracted items with numbered items
cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
1. Widget must render correctly
2. API must return 200
- **Design Decision**: Use React for components
ITEMS

bash "$HOOK" 2>/dev/null
run_test "Items + citations + verified stamp" 0 $?
rm -rf "$SIM_ROOT"

# ============================================================
# Test 2: Items present + NO citations -> exit 2
# ============================================================
echo "--- Test 2: Items present, zero citations -> block ---"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"

echo "testdata" > "$SIM_ROOT/.active-plan"

# Plan with source and verified, but NO [Source:] citations
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test-plan
status: active
source: Research/features/test/research.md
verified: 2026-03-29
---

## Acceptance Criteria
- Widget renders correctly
- API returns 200

## Task Descriptions
### Task 1: Implement widget
Create the widget component at src/Widget.tsx.
PLAN

# Extracted items with content
cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
1. Widget must render correctly
2. API must return 200
- **Design Decision**: Use React for components
ITEMS

bash "$HOOK" 2>/dev/null
run_test "Items present + no citations" 2 $?
rm -rf "$SIM_ROOT"

# ============================================================
# Test 3: Source present + NO verified stamp -> exit 2
# ============================================================
echo "--- Test 3: Source field but no verified stamp -> block ---"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"

echo "testdata" > "$SIM_ROOT/.active-plan"

# Plan with source but NO verified: stamp; has citations to pass Block A
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test-plan
status: active
source: Research/features/test/research.md
---

## Acceptance Criteria
- Widget renders correctly [Source: research.md #1]

## Task Descriptions
### Task 1: Implement widget
Create the widget component at src/Widget.tsx.
PLAN

cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
1. Widget must render correctly
ITEMS

bash "$HOOK" 2>/dev/null
run_test "Source present + no verified stamp" 2 $?
rm -rf "$SIM_ROOT"

# ============================================================
# Test 4: No source field -> exit 0 (skip all checks)
# ============================================================
echo "--- Test 4: No source field -> skip, allow exit ---"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"

echo "testdata" > "$SIM_ROOT/.active-plan"

# Plan WITHOUT source field — no upstream, no checks needed
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test-plan
status: active
---

## Acceptance Criteria
- Widget renders correctly

## Task Descriptions
### Task 1: Implement widget
Create the widget component at src/Widget.tsx.
PLAN

bash "$HOOK" 2>/dev/null
run_test "No source field -> skip all checks" 0 $?
rm -rf "$SIM_ROOT"

# ============================================================
# Test 5: Empty _extracted_items.md (0 items) + no citations -> exit 0
# ============================================================
echo "--- Test 5: Empty extracted items + no citations -> allow ---"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"

echo "testdata" > "$SIM_ROOT/.active-plan"

# Plan with source and verified stamp but no citations
cat > "$SIM_ROOT/testdata/implementation_plan.md" << 'PLAN'
---
skill: serious-plan
slug: test-plan
status: active
source: Research/features/test/research.md
verified: 2026-03-29
---

## Acceptance Criteria
- Widget renders correctly

## Task Descriptions
### Task 1: Implement widget
Create the widget component at src/Widget.tsx.
PLAN

# Empty extracted items file (no numbered items or bold items)
cat > "$SIM_ROOT/testdata/_extracted_items.md" << 'ITEMS'
# Extracted Items
(no items extracted)
ITEMS

bash "$HOOK" 2>/dev/null
run_test "Empty extracted items (0 items) + no citations" 0 $?
rm -rf "$SIM_ROOT"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
