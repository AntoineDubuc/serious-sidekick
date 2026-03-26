#!/bin/bash
# capture-conversation.sh
# Stop hook for /serious-conversation: warns if an active conversation
# session has no summary.md (the final deliverable).
#
# Exit codes:
#   0 = allow exit (no active session, or summary exists)
#   2 = block exit (active session without summary)

# No active conversation session? Allow exit.
[ ! -f ".active-conversation" ] && exit 0

CONV_DIR=$(cat .active-conversation | tr -d '[:space:]')

# No conversation directory? Allow exit.
[ ! -d "$CONV_DIR" ] && exit 0

# Check for summary.md (the wrap-up deliverable)
if [ ! -f "${CONV_DIR}/summary.md" ]; then
  echo "CONVERSATION CAPTURE WARNING" >&2
  echo "" >&2
  echo "Active conversation at ${CONV_DIR} has no summary.md." >&2
  echo "The conversation may not have been wrapped up properly." >&2
  echo "" >&2
  echo "To fix: say 'wrap up' to generate the summary, or" >&2
  echo "run /serious-abandon to abandon this conversation." >&2
  exit 2
fi

exit 0
