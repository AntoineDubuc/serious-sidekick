#!/bin/bash
# capture-research.sh
# Stop hook for /serious-research: warns if an active research
# session has an incomplete research.md (frontmatter status not "done").
#
# Exit codes:
#   0 = allow exit (no active session, or research is done)
#   2 = block exit (active session with incomplete research)

# Source shared guard utility (stdin is consumed and cached in _STOP_HOOK_GUARD_INPUT)
source "$(dirname "$0")/../../_shared/stop-hook-guard.sh" || exit 0
# Source the canonical path helper (shared by all Stop hooks that read breadcrumb contents)
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0
guard_stop_hook_active

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# Dual-read breadcrumb gate (Task 4 of multi-terminal-breadcrumb-collision-verify).
# Prefer the per-session path; fall back to legacy with a stderr WARN.
SKILL=research
PID_BC="${PROJECT_ROOT}/.claude-active/$(claude_pid)-${SKILL}"
LEGACY_BC="${PROJECT_ROOT}/.active-${SKILL}"
if [ -f "$PID_BC" ]; then
  bc="$PID_BC"
elif [ -f "$LEGACY_BC" ]; then
  bc="$LEGACY_BC"
  echo "WARN: dual-read fallback for ${SKILL} from legacy path" >&2
else
  exit 0
fi

RESEARCH_DIR=$(resolve_breadcrumb_path "$bc" "$PROJECT_ROOT") || exit 0
[ -L "$RESEARCH_DIR" ] && exit 0

# No research directory? Allow exit.
[ ! -d "$RESEARCH_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check for research.md
if [ ! -f "${RESEARCH_DIR}/research.md" ]; then
  emit_block_then_exit_2 "RESEARCH CAPTURE WARNING

Active research at ${RESEARCH_DIR} has no research.md.
The research session may not have started properly."
fi

# Check frontmatter only (first 50 lines) for status
FRONTMATTER_STATUS=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^status:" | head -1 | sed 's/status: *//')

# --- Extraction gate check ---
# Research with an upstream source must have _extracted_items.md
SOURCE=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^source:" | sed 's/source: *//' | tr -d '[:space:]')
if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
  if [ ! -f "${RESEARCH_DIR}/_extracted_items.md" ]; then
    emit_block_then_exit_2 "RESEARCH EXTRACTION WARNING

Research at ${RESEARCH_DIR} has a source but no _extracted_items.md.
The upstream extraction gate was skipped."
  fi

  # --- Handoff verifier stamp check ---
  VERIFIED=$(head -50 "${RESEARCH_DIR}/research.md" | grep "^verified:" | head -1)
  if [ -z "$VERIFIED" ]; then
    emit_block_then_exit_2 "TRACEABILITY VERIFICATION WARNING

Research at ${RESEARCH_DIR}/research.md has a source but no verified: stamp.
The handoff-verifier has not run."
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  emit_block_then_exit_2 "ENFORCEMENT ERROR: capture-research.sh did not complete all checks"
fi
exit 0
