#!/bin/bash
# run_tests.sh — Test runner that auto-detects bats-core or falls back to plain bash
#
# Usage: bash tests/run_tests.sh [test_file_or_pattern]
#   No args: runs all tests/test_*.sh files
#   With arg: runs only the specified test file(s)
#
# Auto-discovered test files include:
#   test_status_json.sh — status.json schema compliance (Plan 4a)

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Detect bats-core
if command -v bats >/dev/null 2>&1; then
  USE_BATS=true
else
  USE_BATS=false
fi

# Color output (if terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  RESET=''
fi

run_bash_test() {
  local test_file="$1"
  local test_name
  test_name="$(basename "$test_file")"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if bash "$test_file" >/tmp/serious-test-output.txt 2>&1; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}PASS${RESET}  $test_name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}FAIL${RESET}  $test_name"
    # Show first 20 lines of output on failure
    head -20 /tmp/serious-test-output.txt | sed 's/^/        /'
  fi
}

# Determine which test files to run
if [ $# -gt 0 ]; then
  TEST_FILES=("$@")
else
  TEST_FILES=()
  for f in "$TESTS_DIR"/test_*.sh; do
    [ -f "$f" ] && TEST_FILES+=("$f")
  done
fi

if [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "No test files found."
  exit 1
fi

echo "Running ${#TEST_FILES[@]} test file(s)..."
echo ""

if $USE_BATS; then
  echo "(Using bats-core)"
  bats "${TEST_FILES[@]}"
  exit $?
else
  echo "(Using plain bash runner)"
  echo ""
  for test_file in "${TEST_FILES[@]}"; do
    run_bash_test "$test_file"
  done
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed, $TOTAL_COUNT total"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
else
  exit 0
fi
