#!/bin/bash
# check-verdict.sh
# Stop hook for /serious-review: warns if an active review session
# has no review_verdict.md (review started but never reached a verdict).
#
# Exit codes:
#   0 = allow exit (no active session, or verdict exists)
#   2 = block exit (active session without verdict)

# No active review session? Allow exit.
[ ! -f ".active-review" ] && exit 0

REVIEW_DIR=$(cat .active-review | tr -d '[:space:]')

# No review directory? Allow exit.
[ ! -d "$REVIEW_DIR" ] && exit 0

# Check for review_verdict.md
if [ ! -f "${REVIEW_DIR}/review_verdict.md" ]; then
  echo "REVIEW VERDICT WARNING" >&2
  echo "" >&2
  echo "Active review session at ${REVIEW_DIR} has no review_verdict.md." >&2
  echo "The plan review started but never reached a verdict." >&2
  echo "" >&2
  echo "To fix: complete /serious-review to produce a verdict, or" >&2
  echo "run /serious-abandon to abandon this review." >&2
  exit 2
fi

# --- Anti-rationalization strengthening (Layer 2) ---
# Check that the verdict contains specific references, not just generic approval
if [ -f "${REVIEW_DIR}/review_verdict.md" ]; then
  VERDICT_CONTENT=$(cat "${REVIEW_DIR}/review_verdict.md")
  # Check for review theater: verdict exists but has no file:line references
  HAS_REFS=$(echo "$VERDICT_CONTENT" | grep -cE '[a-zA-Z_/]+\.(ts|js|py|md|sh|yaml|json):[0-9]+|line [0-9]+|lines [0-9]' || true)
  VERDICT_LINE=$(echo "$VERDICT_CONTENT" | grep -i 'verdict:' | head -1)
  # Only flag if verdict says PASS but has zero specific references
  if echo "$VERDICT_LINE" | grep -qi 'pass' && [ "$HAS_REFS" -eq 0 ]; then
    echo "REVIEW QUALITY WARNING" >&2
    echo "" >&2
    echo "Review verdict at ${REVIEW_DIR}/review_verdict.md passed but contains" >&2
    echo "zero file:line references. A substantive review must cite specific" >&2
    echo "locations in the plan, not just generic approval." >&2
    echo "" >&2
    echo "See Guardrail Block entry #1: 'Name at least one specific concern" >&2
    echo "with file path and line number.'" >&2
    exit 2
  fi
fi

exit 0
