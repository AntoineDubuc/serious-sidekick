#!/bin/bash
# test_falsification_baseline.sh — Task 0 RED test for skill-voice-retrofit
#
# Verifies that Research/features/skill-voice-retrofit/evidence/falsification-baseline.md
# captures 5 verbatim historical slop examples in the required structure.
#
# Acceptance criteria (from implementation_plan.md Task 0):
#   AC1: exactly 5 entries, each with 5 required fields
#   AC2: at least 3 entries cite worst-offender skills (/serious-code, /serious-research, /serious-debug)
#   AC3: the user's reference complaint appears verbatim
#   AC4: this test runs and exits 0
#
# Negative tests:
#   FAIL if file has 4 or fewer entries
#   FAIL if any entry is missing any required field
#   FAIL if the reference complaint is not present verbatim

set -uo pipefail

# Resolve project root from this script's location (tests/voice/<script>)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE="$PROJECT_ROOT/Research/features/skill-voice-retrofit/evidence/falsification-baseline.md"

PASS=0
FAIL=0

assert() {
  local name="$1"
  local result="$2"
  local detail="${3:-}"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS+1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL+1))
    echo "  FAIL: $name${detail:+ — $detail}"
  fi
}

echo "=== Task 0 Falsification Baseline ==="

# Existence
if [ -f "$BASELINE" ]; then
  assert "baseline file exists" "pass"
else
  assert "baseline file exists at $BASELINE" "fail" "missing"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# AC1: exactly 5 entries (each entry starts with "## Example N:")
ENTRY_COUNT=$(grep -cE '^## Example [1-9][0-9]*:' "$BASELINE" || true)
if [ "$ENTRY_COUNT" = "5" ]; then
  assert "exactly 5 entries (found $ENTRY_COUNT)" "pass"
else
  assert "exactly 5 entries" "fail" "found $ENTRY_COUNT"
fi

# AC1: each entry has the 5 required field labels (skill, touchpoint, verbatim text, violation, expected verdict)
REQUIRED_FIELDS=(
  '^\*\*Skill:\*\*'
  '^\*\*Touchpoint:\*\*'
  '^\*\*Verbatim text:\*\*'
  '^\*\*Voice-rule violation:\*\*'
  '^\*\*Expected verdict after retrofit:\*\*'
)
FIELD_LABELS=("Skill" "Touchpoint" "Verbatim text" "Voice-rule violation" "Expected verdict after retrofit")
for i in "${!REQUIRED_FIELDS[@]}"; do
  pattern="${REQUIRED_FIELDS[$i]}"
  label="${FIELD_LABELS[$i]}"
  count=$(grep -cE "$pattern" "$BASELINE" || true)
  if [ "$count" -ge 5 ]; then
    assert "field '$label' appears in all 5 entries" "pass"
  else
    assert "field '$label' appears in all 5 entries" "fail" "only $count occurrences"
  fi
done

# AC1: each Expected verdict must be PASS or STILL_FAIL_acceptable
INVALID_VERDICTS=$(grep -E '^\*\*Expected verdict after retrofit:\*\*' "$BASELINE" | grep -cEv 'PASS|STILL_FAIL_acceptable' || true)
if [ "$INVALID_VERDICTS" = "0" ]; then
  assert "all verdicts are PASS or STILL_FAIL_acceptable" "pass"
else
  assert "all verdicts are PASS or STILL_FAIL_acceptable" "fail" "$INVALID_VERDICTS invalid"
fi

# AC2: at least 3 entries cite worst-offender skills (/serious-code, /serious-research, /serious-debug)
# Count Skill lines that name one of the three worst offenders.
WORST_COUNT=$(grep -E '^\*\*Skill:\*\*' "$BASELINE" | grep -cE '/serious-(code|research|debug)([^a-z]|$)' || true)
if [ "$WORST_COUNT" -ge 3 ]; then
  assert "at least 3 entries cite worst-offender skills (found $WORST_COUNT)" "pass"
else
  assert "at least 3 entries cite worst-offender skills" "fail" "found $WORST_COUNT"
fi

# AC3: the user's reference complaint appears verbatim
REFERENCE_QUOTE='I updated 7B in light of plan 3A because the review in plan 01 didn'\''t agree with that'
if grep -qF "$REFERENCE_QUOTE" "$BASELINE"; then
  assert "user's reference complaint present verbatim" "pass"
else
  assert "user's reference complaint present verbatim" "fail" "missing"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
