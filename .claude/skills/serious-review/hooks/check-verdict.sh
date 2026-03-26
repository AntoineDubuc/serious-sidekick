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

exit 0
