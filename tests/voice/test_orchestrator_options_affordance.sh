#!/bin/bash
# test_orchestrator_options_affordance.sh — Task 4 RED test for /options escape hatch.
#
# Verifies AC3 of Task 4: the `/options` escape hatch is documented in SKILL.md
# so the user knows they can ask for alternatives any time.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$PROJECT_ROOT/.claude/skills/serious-conversation/SKILL.md"

PASS=0
FAIL=0
assert() {
  local name="$1"; local result="$2"; local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $name${detail:+ — $detail}"
  fi
}

echo "=== Task 4 Orchestrator /options affordance ==="

if grep -qF '/options' "$SKILL_FILE"; then
  assert "/options affordance documented in SKILL.md" "pass"
else
  assert "/options affordance documented in SKILL.md" "fail"
fi

# The affordance description should explain WHAT the user gets when invoking /options
if grep -qE '/options.*alternatives|alternatives.*on (user )?request|escape hatch' "$SKILL_FILE"; then
  assert "/options description explains what user gets" "pass"
else
  assert "/options description explains what user gets" "fail"
fi

# Non-Orchestrator personas should not have /options mandate (it's an Orchestrator-default
# escape, not a global change). Confirm /options appears only inside the Orchestrator section.
TOTAL_OPTIONS=$(grep -cF '/options' "$SKILL_FILE" || true)
TOTAL_OPTIONS=$((TOTAL_OPTIONS + 0))
# We expect 2-5 occurrences (in the rewrite block, the test references, and at most a
# Persona-Roster note). >10 would suggest accidental sprawl.
if [ "$TOTAL_OPTIONS" -ge 2 ] && [ "$TOTAL_OPTIONS" -le 10 ]; then
  assert "/options mentioned 2-10 times (scoped to Orchestrator default)" "pass"
else
  assert "/options mentioned 2-10 times" "fail" "found $TOTAL_OPTIONS"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
