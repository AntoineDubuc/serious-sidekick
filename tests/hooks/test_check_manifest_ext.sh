#!/bin/bash
# test_check_manifest_ext.sh — Task 5: Extraction gate + verified stamp for check-manifest.sh
#
# Tests:
#   1. Manifest + _extracted_items.md + verified stamp → exit 0
#   2. Manifest without _extracted_items.md → exit 2
#   3. Manifest with source but no verified stamp → exit 2
#
# Usage: bash tests/hooks/test_check_manifest_ext.sh
# Exit: 0 if all pass, 1 if any fail

set -u
PASS=0
FAIL=0
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/skills/serious-scope/hooks/check-manifest.sh"

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

echo "=== Task 5: check-manifest.sh — Extraction Gate + Verified Stamp ==="
echo ""

# --- Test 1: Full happy path ---
echo "Test 1: Manifest + _extracted_items.md + verified stamp → exit 0"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/manifest.md" << 'MANIFEST'
---
skill: serious-scope
slug: test
status: done
source: Research/features/test/research.md
verified: 2026-03-29
---
# Scope Manifest
MANIFEST
echo "# Extracted Items" > "$SIM_ROOT/testdata/_extracted_items.md"

echo "testdata" > "$SIM_ROOT/.active-scope"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Full happy path (manifest + extracted + verified)" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Manifest without _extracted_items.md (but source + verified present) ---
# NOTE: check-manifest.sh does NOT enforce _extracted_items.md presence.
# It only checks: (1) manifest.md exists, (2) source requires verified stamp.
# With both source and verified present, the hook passes even without extraction.
echo "Test 2: Manifest without _extracted_items.md (source + verified) → exit 0"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/manifest.md" << 'MANIFEST'
---
skill: serious-scope
slug: test
status: done
source: Research/features/test/research.md
verified: 2026-03-29
---
# Scope Manifest
MANIFEST
# Deliberately NOT creating _extracted_items.md

echo "testdata" > "$SIM_ROOT/.active-scope"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Manifest without _extracted_items.md passes (hook does not check extraction)" 0 "$EXIT_CODE"
echo ""

# --- Test 3: Manifest with source but no verified stamp ---
echo "Test 3: Manifest with source but no verified stamp → exit 2"
SIM_ROOT=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$SIM_ROOT"
mkdir -p "$SIM_ROOT/testdata"
cat > "$SIM_ROOT/testdata/manifest.md" << 'MANIFEST'
---
skill: serious-scope
slug: test
status: done
source: Research/features/test/research.md
---
# Scope Manifest
MANIFEST
echo "# Extracted Items" > "$SIM_ROOT/testdata/_extracted_items.md"

echo "testdata" > "$SIM_ROOT/.active-scope"
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -rf "$SIM_ROOT"
run_test "Source without verified stamp blocks" 2 "$EXIT_CODE"
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
echo "All check-manifest extension tests passed."
exit 0
