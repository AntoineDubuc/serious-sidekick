#!/bin/bash
# test-hook-susceptibility.sh — Detect loop-prone exit-2 paths in Stop hooks
#
# Usage: bash test-hook-susceptibility.sh <path-to-hook-script>
#
# Implements the 4-part susceptibility test from Thread 4:
#   1. Count exit 2 paths
#   2. Check for stop_hook_active guard
#   3. Verify each exit 2 is gated on a terminal marker
#   4. Simulate loop by running twice with fixed input
#
# Exit codes:
#   0 = hook is NOT susceptible (all 4 checks pass)
#   1 = hook IS susceptible (at least one check failed)

HOOK_PATH="$1"
PASS_COUNT=0
FAIL_COUNT=0

if [ -z "$HOOK_PATH" ] || [ ! -f "$HOOK_PATH" ]; then
  echo "Usage: bash test-hook-susceptibility.sh <path-to-hook-script>" >&2
  exit 1
fi

echo "=== Hook Susceptibility Test ==="
echo "Hook: ${HOOK_PATH}"
echo ""

# Part 1: Count exit 2 paths
EXIT_2_COUNT=$(grep -c 'exit 2' "$HOOK_PATH")
echo "Part 1: exit 2 paths found: ${EXIT_2_COUNT}"
if [ "$EXIT_2_COUNT" -eq 0 ]; then
  echo "  No exit 2 paths — hook cannot block. PASS (trivially safe)."
  exit 0
fi
echo "  Hook has blocking paths — continuing checks."
PASS_COUNT=$((PASS_COUNT + 1))

# Part 2: Check for stop_hook_active guard
if grep -q 'stop_hook_active' "$HOOK_PATH"; then
  echo "Part 2: stop_hook_active guard found. PASS"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "Part 2: No stop_hook_active guard found. FAIL"
  echo "  Hook blocks (exit 2) but never checks stop_hook_active."
  echo "  A forced-continuation loop will re-trigger the block indefinitely."
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Part 3: Verify each exit 2 is gated on a terminal marker
# (i.e., exit 2 only fires when the workflow is in a terminal state)
# We check that every exit 2 line is inside a conditional block
EXIT_2_LINES=$(grep -n 'exit 2' "$HOOK_PATH" | grep -v '^\s*#')
UNGATED_COUNT=0
while IFS= read -r line; do
  LINE_NUM=$(echo "$line" | cut -d: -f1)
  # Check if the line is inside an if/then block by looking at preceding lines
  CONTEXT=$(head -n "$LINE_NUM" "$HOOK_PATH" | tail -n 10)
  if echo "$CONTEXT" | grep -qE 'if |then|&&'; then
    : # gated
  else
    UNGATED_COUNT=$((UNGATED_COUNT + 1))
  fi
done <<< "$EXIT_2_LINES"

if [ "$UNGATED_COUNT" -eq 0 ]; then
  echo "Part 3: All exit 2 paths are inside conditionals. PASS"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "Part 3: ${UNGATED_COUNT} exit 2 path(s) appear ungated. FAIL"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Part 4: Simulate loop — run hook twice with fixed input, check determinism
# If exit code is 2 both times with the same input, the hook would loop.
FIXTURE_DIR=$(mktemp -d)
mkdir -p "${FIXTURE_DIR}/conversations/test-slug"
echo 'conversations/test-slug' > "${FIXTURE_DIR}/.active-conversation"
printf -- '---\nstatus: done\n---\n# Test\n' > "${FIXTURE_DIR}/conversations/test-slug/conversation.md"

CODE1=$(CLAUDE_PROJECT_DIR="$FIXTURE_DIR" bash "$HOOK_PATH" < /dev/null 2>/dev/null; echo $?)
CODE2=$(CLAUDE_PROJECT_DIR="$FIXTURE_DIR" bash "$HOOK_PATH" < /dev/null 2>/dev/null; echo $?)
rm -rf "$FIXTURE_DIR"

if [ "$CODE1" = "2" ] && [ "$CODE2" = "2" ]; then
  echo "Part 4: Hook exits 2 on both runs with fixed input — loop confirmed. FAIL"
  echo "  Run 1: exit ${CODE1}, Run 2: exit ${CODE2}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "Part 4: Hook does not deterministically exit 2. PASS"
  echo "  Run 1: exit ${CODE1}, Run 2: exit ${CODE2}"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

echo ""
echo "=== Result ==="
echo "Passed: ${PASS_COUNT}/4, Failed: ${FAIL_COUNT}/4"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "VERDICT: SUSCEPTIBLE"
  exit 1
else
  echo "VERDICT: NOT SUSCEPTIBLE"
  exit 0
fi
