#!/bin/bash
# verify-guardrails.sh
# Verifies that all 7 SKILL.md files contain the current universal
# anti-rationalization entries from _anti-rationalization-core.md.
#
# Usage:
#   ./scripts/verify-guardrails.sh
#
# Checks each universal entry's Rationalization column text appears
# verbatim in every SKILL.md guardrail block. Exits non-zero on mismatch.

CORE_FILE="_anti-rationalization-core.md"
SKILL_DIR=".claude/skills"
SKILLS="serious-conversation serious-research serious-mock-ups serious-scope serious-plan serious-code serious-review"

# Check core file exists
if [ ! -f "$CORE_FILE" ]; then
  echo "ERROR: $CORE_FILE not found." >&2
  exit 1
fi

# Extract universal rationalization phrases from the core file
# These are the Rationalization column values (between first and second pipe on each data row)
UNIVERSAL_ENTRIES=$(grep '^| U[0-9]' "$CORE_FILE" | sed 's/^| U[0-9]* | //' | sed 's/ |.*//')

if [ -z "$UNIVERSAL_ENTRIES" ]; then
  echo "ERROR: No universal entries found in $CORE_FILE." >&2
  exit 1
fi

ENTRY_COUNT=$(echo "$UNIVERSAL_ENTRIES" | wc -l | tr -d ' ')
echo "Found $ENTRY_COUNT universal entries in $CORE_FILE."
echo ""

# Check each skill
FAILURES=0
for skill in $SKILLS; do
  SKILL_FILE="${SKILL_DIR}/${skill}/SKILL.md"

  if [ ! -f "$SKILL_FILE" ]; then
    echo "MISSING: $SKILL_FILE does not exist."
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Check for guardrail markers
  if ! grep -q '<!-- GUARDRAILS' "$SKILL_FILE"; then
    echo "FAIL: $skill — no <!-- GUARDRAILS marker found."
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Check each universal entry exists in the skill file
  SKILL_MISSING=0
  while IFS= read -r entry; do
    # Trim whitespace
    entry=$(echo "$entry" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$entry" ] && continue

    if ! grep -qF "$entry" "$SKILL_FILE"; then
      echo "FAIL: $skill — missing universal entry: $entry"
      SKILL_MISSING=$((SKILL_MISSING + 1))
    fi
  done <<< "$UNIVERSAL_ENTRIES"

  if [ "$SKILL_MISSING" -eq 0 ]; then
    echo "OK: $skill — all $ENTRY_COUNT universal entries present."
  else
    FAILURES=$((FAILURES + SKILL_MISSING))
  fi
done

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: All 7 skills contain all universal anti-rationalization entries."
  exit 0
else
  echo "FAIL: $FAILURES issues found across skills."
  exit 1
fi
