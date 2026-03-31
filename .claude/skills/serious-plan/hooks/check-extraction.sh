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

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0

# No active plan session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-plan" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-plan" | tr -d '[:space:]')
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
PLAN_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No plan directory? Allow exit.
[ ! -d "$PLAN_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check if there's an implementation_plan.md
# If no plan file exists yet, we're still in Phase 0 — too early to check
# Prioritize implementation_plan.md directly to avoid picking up other .md files
# (review_verdict.md, execution_log.md, etc.) in the same directory
if [ -f "${PLAN_DIR}/implementation_plan.md" ]; then
  HAS_PLAN="${PLAN_DIR}/implementation_plan.md"
else
  HAS_PLAN=$(find "$PLAN_DIR" -name "implementation_plan.md" 2>/dev/null | head -1)
fi
[ -z "$HAS_PLAN" ] && exit 0

# Plan exists — check if _extracted_items.md exists
if [ ! -f "${PLAN_DIR}/_extracted_items.md" ]; then
  # Check if the plan has a source field (upstream artifact)
  # If no source, extraction isn't needed
  SOURCE=$(head -50 "$HAS_PLAN" | grep "^source:" | sed 's/source: *//')
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

# --- Citation cross-reference check ---
# Verify the plan actually USED the extracted items (not just created the file)
if [ -f "${PLAN_DIR}/_extracted_items.md" ] && [ -n "$HAS_PLAN" ] && [ -f "$HAS_PLAN" ]; then
  ITEM_COUNT=$(grep -cE '^\s*[0-9]+\.|^\s*- \*\*' "${PLAN_DIR}/_extracted_items.md" || true)
  SOURCE_CITATIONS=$(grep -ci '\[source:' "$HAS_PLAN" || true)

  if [ "$ITEM_COUNT" -gt 0 ] && [ "$SOURCE_CITATIONS" -eq 0 ]; then
    echo "EXTRACTION CROSS-REFERENCE WARNING" >&2
    echo "" >&2
    echo "Plan at ${HAS_PLAN} has ${ITEM_COUNT} extracted upstream items" >&2
    echo "but ZERO [Source:] citations in acceptance criteria." >&2
    echo "" >&2
    echo "This means the extracted items were not cross-referenced during" >&2
    echo "plan generation. Every acceptance criterion must cite its source." >&2
    exit 2
  fi
fi

# --- Anti-rationalization strengthening (Layer 2) ---
# Check the plan file for hedge language in task descriptions
if [ -n "$HAS_PLAN" ] && [ -f "$HAS_PLAN" ]; then
  TASK_SECTION=$(sed -n '/^## Task Descriptions/,$ p' "$HAS_PLAN" 2>/dev/null)
  if [ -n "$TASK_SECTION" ]; then
    HEDGE=$(echo "$TASK_SECTION" | grep -inE 'consider whether|you might want to|think about|it may be worth|as appropriate|optionally' | head -5)
    if [ -n "$HEDGE" ]; then
      echo "HEDGE LANGUAGE WARNING" >&2
      echo "" >&2
      echo "Plan at ${HAS_PLAN} contains hedge language in task descriptions:" >&2
      echo "$HEDGE" | while IFS= read -r line; do echo "  $line" >&2; done
      echo "" >&2
      echo "Plans must use specific, imperative language. See Guardrail Block entry #3." >&2
      echo "Resolve every 'consider' into a decision with file:line reference." >&2
      exit 2
    fi
  fi
fi

# --- Handoff verifier stamp check ---
# Plans with upstream sources must have verified: stamp from handoff-verifier
if [ -n "$HAS_PLAN" ] && [ -f "$HAS_PLAN" ]; then
  SOURCE=$(head -50 "$HAS_PLAN" | grep "^source:" | sed 's/source: *//' | tr -d '[:space:]')
  if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
    VERIFIED=$(head -50 "$HAS_PLAN" | grep "^verified:" | head -1)
    if [ -z "$VERIFIED" ]; then
      echo "TRACEABILITY VERIFICATION WARNING" >&2
      echo "" >&2
      echo "Plan at ${HAS_PLAN} has a source but no verified: stamp." >&2
      echo "The handoff-verifier has not run. Run Phase 3 verification." >&2
      exit 2
    fi
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: check-extraction.sh did not complete all checks" >&2
  exit 2
fi
exit 0
