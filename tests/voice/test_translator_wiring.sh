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

# AC3: /serious-research Phase 6 handoff — must be section-scoped, not file-wide grep.
# Extract the Phase 6 block (from "## Phase 6: Handoff" to the next "## " heading).
research_md="$PROJECT_ROOT/.claude/skills/serious-research/SKILL.md"
phase_6_block=$(awk '
  /^## Phase 6: Handoff/ { in_block=1; next }
  in_block && /^## / { exit }
  in_block { print }
' "$research_md")

if [ -z "$phase_6_block" ]; then
  assert "serious-research Phase 6 section exists" "fail" "no '## Phase 6: Handoff' heading found"
else
  assert "serious-research Phase 6 section exists" "pass"
fi

# Inside the Phase 6 block, REQUIRE one of:
# (a) the literal deferral marker (per Task 3 AC3 wording), OR
# (b) an explicit voice-translator dispatch instruction
if echo "$phase_6_block" | grep -qF 'voice-retrofit: manual rewrite — translator deferred'; then
  assert "serious-research Phase 6 has literal deferral marker" "pass"
elif echo "$phase_6_block" | grep -qE 'dispatch.*voice-translator|invoke.*voice-translator|spawn.*voice-translator'; then
  assert "serious-research Phase 6 dispatches voice-translator" "pass"
else
  assert "serious-research Phase 6 has deferral marker OR translator dispatch" "fail" "neither pattern found in the Phase 6 block"
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
