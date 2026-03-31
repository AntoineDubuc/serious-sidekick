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

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0

# No active conversation session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-conversation" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-conversation" | tr -d '[:space:]')
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
CONV_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No conversation directory? Allow exit.
[ ! -d "$CONV_DIR" ] && exit 0

# Check if conversation.md exists
[ ! -f "${CONV_DIR}/conversation.md" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Only block if status is "done" but summary is missing
# If status is "active", the user is still working — don't block
FRONTMATTER_STATUS=$(head -50 "${CONV_DIR}/conversation.md" | grep "^status:" | head -1 | sed 's/status: *//')

if [ "$FRONTMATTER_STATUS" = "done" ] && [ ! -f "${CONV_DIR}/summary.md" ]; then
  echo "CONVERSATION CAPTURE WARNING" >&2
  echo "" >&2
  echo "Conversation at ${CONV_DIR} is marked done but has no summary.md." >&2
  echo "The conversation was closed without generating a summary." >&2
  echo "" >&2
  echo "To fix: reopen the conversation and say 'wrap up'." >&2
  exit 2
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: capture-conversation.sh did not complete all checks" >&2
  exit 2
fi
exit 0
