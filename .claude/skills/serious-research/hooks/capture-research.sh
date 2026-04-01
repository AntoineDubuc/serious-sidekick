#!/bin/bash
# capture-research.sh
# Stop hook for /serious-research: warns if an active research
# session has an incomplete research.md (frontmatter status not "done").
#
# Exit codes:
#   0 = allow exit (no active session, or research is done)
#   2 = block exit (active session with incomplete research)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active research session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-research" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-research" | tr -d '[:space:]')
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
RESEARCH_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No research directory? Allow exit.
[ ! -d "$RESEARCH_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

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
FRONTMATTER_STATUS=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^status:" | head -1 | sed 's/status: *//')

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

# --- Extraction gate check ---
# Research with an upstream source must have _extracted_items.md
SOURCE=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^source:" | sed 's/source: *//' | tr -d '[:space:]')
if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
  if [ ! -f "${RESEARCH_DIR}/_extracted_items.md" ]; then
    echo "RESEARCH EXTRACTION WARNING" >&2
    echo "" >&2
    echo "Research at ${RESEARCH_DIR} has a source but no _extracted_items.md." >&2
    echo "The upstream extraction gate was skipped." >&2
    exit 2
  fi

  # --- Handoff verifier stamp check ---
  VERIFIED=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^verified:" | head -1)
  if [ -z "$VERIFIED" ]; then
    echo "TRACEABILITY VERIFICATION WARNING" >&2
    echo "" >&2
    echo "Research at ${RESEARCH_DIR}/research.md has a source but no verified: stamp." >&2
    echo "The handoff-verifier has not run." >&2
    exit 2
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: capture-research.sh did not complete all checks" >&2
  exit 2
fi
exit 0
