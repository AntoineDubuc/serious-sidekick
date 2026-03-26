#!/bin/bash
# hedge-language-gate.sh
# PreToolUse hook for /serious-plan: blocks Write if the content
# contains hedge language that produces vague plans.
#
# Only active during /serious-plan sessions (checks .active-plan breadcrumb).
# Scans the content being written for banned patterns.
#
# Exit codes:
#   0 = allow (no active session, no hedge language, or non-plan file)
#   2 = block (hedge language detected in plan content)

# No active plan session? Allow.
[ ! -f ".active-plan" ] && exit 0

# Parse file path from tool input
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

[ -z "$FILE_PATH" ] && exit 0

# Only check plan files (implementation_plan.md or files in plans/)
BASENAME=$(basename "$FILE_PATH")
echo "$FILE_PATH" | grep -qiE 'implementation_plan\.md|/plans/' || exit 0

# Extract content from tool input (between first and last quotes of content field)
CONTENT=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"content"[[:space:]]*:[[:space:]]*"' | head -1)
[ -z "$CONTENT" ] && exit 0

# Check for hedge patterns in the raw tool input (content field)
# These are the exact patterns from the guardrail table
VIOLATIONS=$(echo "$CLAUDE_TOOL_INPUT" | grep -ioE 'consider whether|you might want to|think about|it may be worth|as appropriate|if needed|optionally' | head -5)

if [ -n "$VIOLATIONS" ]; then
  echo "HEDGE LANGUAGE DETECTED in plan content." >&2
  echo "" >&2
  echo "File: ${FILE_PATH}" >&2
  echo "Violations found:" >&2
  echo "$VIOLATIONS" | while read -r v; do echo "  - \"$v\"" >&2; done
  echo "" >&2
  echo "Plans must use specific, imperative language. Name the file, the function," >&2
  echo "the type. Do not defer decisions to the implementer." >&2
  echo "" >&2
  echo "See Guardrail Block entry #3 in /serious-plan SKILL.md." >&2
  exit 2
fi

exit 0
