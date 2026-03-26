#!/bin/bash
# check-extraction.sh
# Stop hook for /serious-plan: warns if an active plan session
# has no _extracted_items.md (the extraction gate was skipped).
#
# This is the hook that catches the 2026-03-22 failure — a plan
# generated from a 36-item conversation that missed 4 design decisions
# because extraction was skipped entirely.
#
# Exit codes:
#   0 = allow exit (no active session, or extraction exists, or no upstream)
#   2 = block exit (active session with upstream but no extraction)

# No active plan session? Allow exit.
[ ! -f ".active-plan" ] && exit 0

PLAN_DIR=$(cat .active-plan | tr -d '[:space:]')

# No plan directory? Allow exit.
[ ! -d "$PLAN_DIR" ] && exit 0

# Check if there's an implementation_plan.md or any plan file
# If no plan file exists yet, we're still in Phase 0 — too early to check
HAS_PLAN=$(find "$PLAN_DIR" -name "implementation_plan.md" -o -name "*.md" -path "*/plans/*" 2>/dev/null | head -1)
[ -z "$HAS_PLAN" ] && exit 0

# Plan exists — check if _extracted_items.md exists
if [ ! -f "${PLAN_DIR}/_extracted_items.md" ]; then
  # Check if the plan has a source field (upstream artifact)
  # If no source, extraction isn't needed
  SOURCE=$(head -20 "$HAS_PLAN" | grep "^source:" | sed 's/source: *//')
  if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
    echo "PLAN EXTRACTION WARNING" >&2
    echo "" >&2
    echo "Plan at ${PLAN_DIR} has no _extracted_items.md." >&2
    echo "The upstream extraction gate (Phase 0d) was skipped." >&2
    echo "Source artifact: ${SOURCE}" >&2
    echo "" >&2
    echo "This plan may have gaps — items from the upstream artifact" >&2
    echo "were not inventoried before generation." >&2
    echo "" >&2
    echo "To fix: run Phase 0d extraction, then re-verify the plan." >&2
    exit 2
  fi
fi

exit 0
