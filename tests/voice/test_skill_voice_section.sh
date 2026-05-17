#!/bin/bash
# test_skill_voice_section.sh — Task 1 RED test for SKILL.md ## Voice sections.
#
# Verifies AC2 of implementation_plan.md Task 1: all 13 SKILL.md files (excluding
# serious-research/SKILL.md which was already retrofitted in commit 736ef45) have
# a `## Voice` section.
#
# Implementation note: we add ## Voice to all 14 files for uniformity (the
# canonical lint AC11 expects 24 surfaces, including all 14 SKILL.md). AC2's
# "13 of 14 grep matches" is satisfied with 14 of 14.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

EXPECTED_SKILLS=(
  serious-abandon
  serious-bananas
  serious-code
  serious-conversation
  serious-debug
  serious-init
  serious-mock-ups
  serious-plan
  serious-prospect-research
  serious-research
  serious-review
  serious-scope
  serious-status
  serious-youtube-tldr
)

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

echo "=== Task 1 SKILL.md voice sections ==="

VOICE_COUNT=0
for skill in "${EXPECTED_SKILLS[@]}"; do
  path="$SKILLS_DIR/$skill/SKILL.md"
  if [ ! -f "$path" ]; then
    assert "$skill/SKILL.md exists" "fail" "missing"
    continue
  fi

  if grep -q '^## Voice' "$path"; then
    VOICE_COUNT=$((VOICE_COUNT+1))
    assert "$skill/SKILL.md has ## Voice section" "pass"
  else
    assert "$skill/SKILL.md has ## Voice section" "fail"
    continue
  fi

  for rule in "What this does" "What I need from you" "What you need to set up first" "Question"; do
    if grep -qF "$rule" "$path"; then
      assert "  $skill references rule: $rule" "pass"
    else
      assert "  $skill references rule: $rule" "fail"
    fi
  done
done

# AC2 test: at least 13 of 14 SKILL.md files have ## Voice (we expect 14)
if [ "$VOICE_COUNT" -ge 13 ]; then
  assert "at least 13 of 14 SKILL.md have ## Voice section (found $VOICE_COUNT)" "pass"
else
  assert "at least 13 of 14 SKILL.md have ## Voice section" "fail" "found $VOICE_COUNT"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
