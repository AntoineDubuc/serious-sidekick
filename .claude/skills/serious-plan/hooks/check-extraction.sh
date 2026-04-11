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

# Source shared guard utility (stdin is consumed and cached in _STOP_HOOK_GUARD_INPUT)
source "$(dirname "$0")/../../_shared/stop-hook-guard.sh" || exit 0
guard_stop_hook_active

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

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
    emit_block_then_exit_2 "PLAN EXTRACTION WARNING

Plan at ${PLAN_DIR} has no _extracted_items.md.
The upstream extraction gate (Phase 0d) was skipped.
Source artifact: ${SOURCE}

This plan may have gaps — items from the upstream artifact
were not inventoried before generation."
  fi
fi

# --- Citation cross-reference check ---
# Verify the plan actually USED the extracted items (not just created the file)
if [ -f "${PLAN_DIR}/_extracted_items.md" ] && [ -n "$HAS_PLAN" ] && [ -f "$HAS_PLAN" ]; then
  ITEM_COUNT=$(grep -cE '^\s*[0-9]+\.|^\s*- \*\*' "${PLAN_DIR}/_extracted_items.md" || true)
  SOURCE_CITATIONS=$(grep -ci '\[source:' "$HAS_PLAN" || true)

  if [ "$ITEM_COUNT" -gt 0 ] && [ "$SOURCE_CITATIONS" -eq 0 ]; then
    emit_block_then_exit_2 "EXTRACTION CROSS-REFERENCE WARNING

Plan at ${HAS_PLAN} has ${ITEM_COUNT} extracted upstream items
but ZERO [Source:] citations in acceptance criteria.

The extracted items were not cross-referenced during plan generation.
Every acceptance criterion must cite its source."
  fi
fi

# --- Anti-rationalization strengthening (Layer 2) ---
# Check the plan file for hedge language in task descriptions
if [ -n "$HAS_PLAN" ] && [ -f "$HAS_PLAN" ]; then
  TASK_SECTION=$(sed -n '/^## Task Descriptions/,$ p' "$HAS_PLAN" 2>/dev/null)
  if [ -n "$TASK_SECTION" ]; then
    HEDGE=$(echo "$TASK_SECTION" | grep -inE 'consider whether|you might want to|think about|it may be worth|as appropriate|optionally' | head -5)
    if [ -n "$HEDGE" ]; then
      HEDGE_MSG="HEDGE LANGUAGE WARNING

Plan at ${HAS_PLAN} contains hedge language in task descriptions:
$(echo "$HEDGE" | sed 's/^/  /')

Plans must use specific language. See Guardrail Block entry #3.
Every 'consider' should be a decision with file:line reference."
      emit_block_then_exit_2 "$HEDGE_MSG"
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
      emit_block_then_exit_2 "TRACEABILITY VERIFICATION WARNING

Plan at ${HAS_PLAN} has a source but no verified: stamp.
The handoff-verifier has not run."
    fi
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  emit_block_then_exit_2 "ENFORCEMENT ERROR: check-extraction.sh did not complete all checks"
fi
exit 0
