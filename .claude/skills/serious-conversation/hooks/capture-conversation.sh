#!/bin/bash
# capture-conversation.sh
# Stop hook for /serious-conversation: warns if a conversation
# was marked done but has no summary.md.
#
# IMPORTANT: Only warns when frontmatter status is "done" without
# a summary. Does NOT block during active conversations — the user
# is still working. Blocking mid-conversation is disruptive.
#
# Exit codes:
#   0 = allow exit (no active session, still in progress, or summary exists)
#   2 = block exit (status is "done" but no summary — skill claimed to finish without delivering)

# No active conversation session? Allow exit.
[ ! -f ".active-conversation" ] && exit 0

CONV_DIR=$(cat .active-conversation | tr -d '[:space:]')

# No conversation directory? Allow exit.
[ ! -d "$CONV_DIR" ] && exit 0

# Check if conversation.md exists
[ ! -f "${CONV_DIR}/conversation.md" ] && exit 0

# Only block if status is "done" but summary is missing
# If status is "active", the user is still working — don't block
FRONTMATTER_STATUS=$(head -20 "${CONV_DIR}/conversation.md" | grep "^status:" | head -1 | sed 's/status: *//')

if [ "$FRONTMATTER_STATUS" = "done" ] && [ ! -f "${CONV_DIR}/summary.md" ]; then
  echo "CONVERSATION CAPTURE WARNING" >&2
  echo "" >&2
  echo "Conversation at ${CONV_DIR} is marked done but has no summary.md." >&2
  echo "The conversation was closed without generating a summary." >&2
  echo "" >&2
  echo "To fix: reopen the conversation and say 'wrap up'." >&2
  exit 2
fi

exit 0
