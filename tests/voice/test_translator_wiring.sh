#!/bin/bash
# test_translator_wiring.sh — Task 3 RED test for translator dispatch wiring.
#
# Verifies AC3-6 of Task 3: the 4 highest-value touchpoints invoke the voice-translator:
#   AC3: /serious-research Phase 6 handoff (manual rewrite OR translator dispatch)
#   AC4: /serious-plan Phase 3 presentation
#   AC5: /serious-code per-task report
#   AC6: /serious-review verdict reveal
#
# Each skill's SKILL.md should contain a dispatch reference to `voice-translator`
# or — for serious-research specifically — a documented "manual rewrite" marker.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

echo "=== Task 3 translator-wiring check ==="

# AC3: /serious-research Phase 6 handoff
research_md="$PROJECT_ROOT/.claude/skills/serious-research/SKILL.md"
if grep -qF 'voice-translator' "$research_md"; then
  assert "serious-research wires translator OR has manual-rewrite marker" "pass"
elif grep -qF 'voice-retrofit: manual rewrite' "$research_md"; then
  assert "serious-research has manual-rewrite marker (commit 736ef45)" "pass"
else
  assert "serious-research wires translator OR has manual-rewrite marker" "fail"
fi

# AC4-6: /serious-plan, /serious-code, /serious-review must all dispatch the translator
for skill in serious-plan serious-code serious-review; do
  path="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"
  if grep -qF 'voice-translator' "$path"; then
    assert "$skill dispatches voice-translator" "pass"
  else
    assert "$skill dispatches voice-translator" "fail"
  fi

  # Each dispatch block should reference the fallback sentinel (AC7)
  if grep -qF 'TRANSLATOR_ERROR' "$path"; then
    assert "$skill references fallback sentinel TRANSLATOR_ERROR" "pass"
  else
    assert "$skill references fallback sentinel TRANSLATOR_ERROR" "fail"
  fi

  # Each dispatch block should describe the 10s timeout / no-retry policy (AC8)
  if grep -qE '(10[- ]?second|10s)\s*(timeout|budget|cap)' "$path" \
     || grep -qE 'no.?retry|no automatic retr' "$path"; then
    assert "$skill documents 10s timeout / no-retry policy" "pass"
  else
    assert "$skill documents 10s timeout / no-retry policy" "fail"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
