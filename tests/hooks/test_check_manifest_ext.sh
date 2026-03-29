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
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR"
cat > "$TMPDIR/manifest.md" << 'MANIFEST'
---
skill: serious-scope
slug: test
status: done
source: Research/features/test/research.md
verified: 2026-03-29
---
# Scope Manifest
MANIFEST
echo "# Extracted Items" > "$TMPDIR/_extracted_items.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-scope
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -f .active-scope
rm -rf "$TMPDIR"
run_test "Full happy path (manifest + extracted + verified)" 0 "$EXIT_CODE"
echo ""

# --- Test 2: Manifest without _extracted_items.md ---
echo "Test 2: Manifest without _extracted_items.md → exit 2"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR"
cat > "$TMPDIR/manifest.md" << 'MANIFEST'
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

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-scope
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -f .active-scope
rm -rf "$TMPDIR"
run_test "Manifest without _extracted_items.md blocks" 2 "$EXIT_CODE"
echo ""

# --- Test 3: Manifest with source but no verified stamp ---
echo "Test 3: Manifest with source but no verified stamp → exit 2"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR"
cat > "$TMPDIR/manifest.md" << 'MANIFEST'
---
skill: serious-scope
slug: test
status: done
source: Research/features/test/research.md
---
# Scope Manifest
MANIFEST
echo "# Extracted Items" > "$TMPDIR/_extracted_items.md"

cd "$PROJECT_ROOT"
echo "$TMPDIR" > .active-scope
bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
rm -f .active-scope
rm -rf "$TMPDIR"
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
