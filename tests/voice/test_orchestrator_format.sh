#!/bin/bash
# test_orchestrator_format.sh — Task 4 RED test for Orchestrator default format.
#
# Verifies AC1, AC2, AC4 of Task 4: Orchestrator template no longer mandates
# multiple-alternatives by default; specifies single-recommendation as the
# default; example questions follow the voice-card structure.

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

echo "=== Task 4 Orchestrator format ==="

# AC1: Orchestrator template no longer mandates "3-5 alternatives" or "3-5 options"
if grep -qE '3-5 (alternatives|options)' "$SKILL_FILE"; then
  assert "no '3-5 alternatives' or '3-5 options' mandate in SKILL.md" "fail"
else
  assert "no '3-5 alternatives' or '3-5 options' mandate in SKILL.md" "pass"
fi

# AC2: single-recommendation default present
if grep -qiE 'recommendation.*trade-off|trade-off in one line|ONE recommendation' "$SKILL_FILE"; then
  assert "single-recommendation default specified" "pass"
else
  assert "single-recommendation default specified" "fail"
fi

# AC4: extract the Orchestrator question example region and verify voice-card structure
# The example follows the "When the Orchestrator has questions" section header.
# Locate the section, then check that the example block (the next 20 lines after
# the section header) contains the PM voice card structure markers.
ORCH_SECTION_LINE=$(grep -nF '**When the Orchestrator has questions for the user**' "$SKILL_FILE" | head -1 | cut -d: -f1)
if [ -z "$ORCH_SECTION_LINE" ]; then
  assert "Orchestrator question section exists" "fail"
else
  assert "Orchestrator question section exists" "pass"
  # Extract ONLY the `Example:` blockquote (lines starting with `> ` after the
  # `Example:` marker), up to the next non-quote non-blank line. This is the actual
  # text the agent emits; meta-text describing the rule is excluded.
  example_block=$(awk -v start="$ORCH_SECTION_LINE" '
    NR < start { next }
    /^Example:/ { in_marker=1; next }
    in_marker && /^>/ { in_block=1; print; next }
    in_block && /^>/ { print; next }
    in_block && /^[^>]/ { exit }
  ' "$SKILL_FILE")

  if echo "$example_block" | grep -qF 'What this does'; then
    assert "example uses 'What this does' (voice-card structure)" "pass"
  else
    assert "example uses 'What this does' (voice-card structure)" "fail"
  fi
  if echo "$example_block" | grep -qF 'Question:'; then
    assert "example ends with 'Question:' (voice-card structure)" "pass"
  else
    assert "example ends with 'Question:' (voice-card structure)" "fail"
  fi
  # No bare ordinal options in the example blockquote itself
  if echo "$example_block" | grep -qE '\bOption [0-9]\b'; then
    assert "example has no bare 'Option N' in the blockquote" "fail" "$(echo "$example_block" | grep -E '\bOption [0-9]\b' | head -1)"
  else
    assert "example has no bare 'Option N' in the blockquote" "pass"
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
