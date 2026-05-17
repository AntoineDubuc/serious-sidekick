#!/bin/bash
# test_status_abandon_framing.sh — Task 5 RED test for status/abandon wrap-up framing.
#
# Verifies AC1, AC2 of Task 5: /serious-status and /serious-abandon wrap-up sections
# use the PM voice-card structure. Slugs and paths still appear (necessary content)
# but the framing leads with plain-English summary.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUS_MD="$PROJECT_ROOT/.claude/skills/serious-status/SKILL.md"
ABANDON_MD="$PROJECT_ROOT/.claude/skills/serious-abandon/SKILL.md"

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

echo "=== Task 5 status/abandon framing ==="

# AC1: /serious-status wrap-up uses voice-card framing.
# Phase 6 (Empty State) has a "What this does" block; Phase 5 (Warnings) uses
# plain-English warnings; Phase 4b (Status glyphs) uses plain-English meanings.
if grep -qF "What this does: nothing's running right now" "$STATUS_MD"; then
  assert "/serious-status empty-state uses 'What this does' framing" "pass"
else
  assert "/serious-status empty-state uses 'What this does' framing" "fail"
fi

# Phase 4b glyphs: "in progress right now" instead of "active (breadcrumb exists)"
if grep -qF "in progress right now" "$STATUS_MD"; then
  assert "/serious-status glyph legend uses plain English (no 'breadcrumb' jargon)" "pass"
else
  assert "/serious-status glyph legend uses plain English" "fail"
fi

# Phase 5 warnings: rewritten to plain English (no 'breadcrumb', 'frontmatter', 'YAML' in warning text)
# Extract from "## Phase 5: Warnings" header to the NEXT `## ` heading (not the same one).
warning_block=$(awk '
  /^## Phase 5: Warnings/ { in_block=1; next }
  in_block && /^## / { exit }
  in_block { print }
' "$STATUS_MD")
if echo "$warning_block" | grep -qF "Workflow record"; then
  assert "/serious-status warnings use plain English ('Workflow record')" "pass"
else
  assert "/serious-status warnings use plain English" "fail" "warning block: $warning_block"
fi

# AC2: /serious-abandon final-report message uses voice-card framing.
if grep -qF "What this does: dropped the inner piece" "$ABANDON_MD"; then
  assert "/serious-abandon final-report uses 'What this does' framing" "pass"
else
  assert "/serious-abandon final-report uses 'What this does' framing" "fail"
fi

# AC2: /serious-abandon next-step suggestion is single-recommendation, not 4-option menu
if grep -qF "ONE next step in plain English" "$ABANDON_MD" || grep -qF "Just one recommendation" "$ABANDON_MD"; then
  assert "/serious-abandon next-step is single-recommendation" "pass"
else
  assert "/serious-abandon next-step is single-recommendation" "fail"
fi

# Negative: slugs/paths still mentioned (necessary content) — confirm /serious-status
# still references its actual data (the workflow path column in the table)
if grep -qF "Research/features" "$STATUS_MD"; then
  assert "/serious-status retains workflow path content (not erased)" "pass"
else
  assert "/serious-status retains workflow path content" "fail"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
