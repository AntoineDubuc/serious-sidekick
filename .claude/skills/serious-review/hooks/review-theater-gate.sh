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
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active review session? Allow (not logged — PreToolUse fires too often to log inactive sessions).
[ ! -f "${PROJECT_ROOT}/.active-review" ] && exit 0

# Source observability helper (diagnostic only — not a security control).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/log-outcome.sh" 2>/dev/null || true

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Parse file path from tool input
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

if [ -z "$FILE_PATH" ]; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "no-file-path"
  exit 0
fi

# Only check verdict files
BASENAME=$(basename "$FILE_PATH")
if ! echo "$BASENAME" | grep -qiE 'verdict'; then
  type _log_outcome >/dev/null 2>&1 && _log_outcome SKIP "non-verdict-file"
  exit 0
fi

# Check for review theater patterns in content
THEATER=$(echo "$CLAUDE_TOOL_INPUT" | grep -ioE 'no (significant )?issues found|looks good|LGTM|no concerns|all good|passes all checks' | head -3)

if [ -n "$THEATER" ]; then
  # Check if there are also specific file references (indicates real review)
  SPECIFICS=$(echo "$CLAUDE_TOOL_INPUT" | grep -oE '[a-zA-Z_/]+\.(ts|tsx|js|jsx|py|rb|go|rs|java|kt|c|cpp|cs|swift|md|sh|bash|yaml|yml|json|toml|css|scss|html|vue|svelte):[0-9]+' | head -1)

  if [ -z "$SPECIFICS" ]; then
    type _log_outcome >/dev/null 2>&1 && _log_outcome BLOCK "review-theater-no-specifics"
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
  type _log_outcome >/dev/null 2>&1 && _log_outcome ERROR "checks-not-reached"
  echo "ENFORCEMENT ERROR: review-theater-gate.sh did not complete all checks" >&2
  exit 2
fi

type _log_outcome >/dev/null 2>&1 && _log_outcome PASS "substantive-review"
exit 0
