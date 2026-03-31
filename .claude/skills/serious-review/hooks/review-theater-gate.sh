#!/bin/bash
# review-theater-gate.sh
# PreToolUse hook for /serious-review: blocks Write of review verdicts
# that constitute review theater (generic approval without specifics).
#
# Only active during /serious-review sessions (checks .active-review breadcrumb).
#
# Exit codes:
#   0 = allow (no active session, non-verdict file, or substantive review)
#   2 = block (review theater detected)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0

# No active review session? Allow.
[ ! -f "${PROJECT_ROOT}/.active-review" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Parse file path from tool input
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

[ -z "$FILE_PATH" ] && exit 0

# Only check verdict files
BASENAME=$(basename "$FILE_PATH")
echo "$BASENAME" | grep -qiE 'verdict' || exit 0

# Check for review theater patterns in content
THEATER=$(echo "$CLAUDE_TOOL_INPUT" | grep -ioE 'no (significant )?issues found|looks good|LGTM|no concerns|all good|passes all checks' | head -3)

if [ -n "$THEATER" ]; then
  # Check if there are also specific file references (indicates real review)
  SPECIFICS=$(echo "$CLAUDE_TOOL_INPUT" | grep -oE '[a-zA-Z_/]+\.(ts|tsx|js|jsx|py|rb|go|rs|java|kt|c|cpp|cs|swift|md|sh|bash|yaml|yml|json|toml|css|scss|html|vue|svelte):[0-9]+' | head -1)

  if [ -z "$SPECIFICS" ]; then
    echo "REVIEW THEATER DETECTED" >&2
    echo "" >&2
    echo "File: ${FILE_PATH}" >&2
    echo "Patterns found:" >&2
    echo "$THEATER" | while read -r t; do echo "  - \"$t\"" >&2; done
    echo "" >&2
    echo "A review must name at least one specific concern with file path" >&2
    echo "and line number. If genuinely no issues, explain what you checked" >&2
    echo "and why it's correct." >&2
    echo "" >&2
    echo "See Guardrail Block entry #1 in /serious-review SKILL.md." >&2
    exit 2
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: review-theater-gate.sh did not complete all checks" >&2
  exit 2
fi
exit 0
