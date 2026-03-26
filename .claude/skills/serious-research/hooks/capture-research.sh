#!/bin/bash
# capture-research.sh
# Stop hook for /serious-research: warns if an active research
# session has an incomplete research.md (frontmatter status not "done").
#
# Exit codes:
#   0 = allow exit (no active session, or research is done)
#   2 = block exit (active session with incomplete research)

# No active research session? Allow exit.
[ ! -f ".active-research" ] && exit 0

RESEARCH_DIR=$(cat .active-research | tr -d '[:space:]')

# No research directory? Allow exit.
[ ! -d "$RESEARCH_DIR" ] && exit 0

# Check for research.md
if [ ! -f "${RESEARCH_DIR}/research.md" ]; then
  echo "RESEARCH CAPTURE WARNING" >&2
  echo "" >&2
  echo "Active research at ${RESEARCH_DIR} has no research.md." >&2
  echo "The research session may not have started properly." >&2
  exit 2
fi

# Check frontmatter only (first 20 lines) for status
# This avoids matching "status: active" in code examples within the body
FRONTMATTER_STATUS=$(head -20 "${RESEARCH_DIR}/research.md" | grep "^status:" | head -1 | sed 's/status: *//')

if [ "$FRONTMATTER_STATUS" = "active" ]; then
  echo "RESEARCH CAPTURE WARNING" >&2
  echo "" >&2
  echo "Active research at ${RESEARCH_DIR} is still in progress (status: active)." >&2
  echo "Findings may be incomplete. The research has not been finalized." >&2
  echo "" >&2
  echo "To fix: complete the research phases, or" >&2
  echo "run /serious-abandon to abandon this research." >&2
  exit 2
fi

exit 0
