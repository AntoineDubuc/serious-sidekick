#!/bin/bash
# check-manifest.sh
# Stop hook for /serious-scope: warns if an active scope session
# has no manifest.md (scoping started but never produced output).
#
# Exit codes:
#   0 = allow exit (no active session, or manifest exists)
#   2 = block exit (active session without manifest)

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
SKILL=scope
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

SCOPE_DIR=$(resolve_breadcrumb_path "$bc" "$PROJECT_ROOT") || exit 0
[ -L "$SCOPE_DIR" ] && exit 0

# No scope directory? Allow exit.
[ ! -d "$SCOPE_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check for manifest.md
if [ ! -f "${SCOPE_DIR}/manifest.md" ]; then
  emit_block_then_exit_2 "SCOPE MANIFEST WARNING

Active scope session at ${SCOPE_DIR} has no manifest.md.
Scoping started but never produced a manifest."
fi

# --- Extraction gate + verifier stamp (only when upstream source exists) ---
# Only require extraction and verification when the manifest has an upstream source.
# Scopes created from scratch (no source:) don't need extraction.
SOURCE=$(head -50 "${SCOPE_DIR}/manifest.md" | grep "^source:" | sed 's/source: *//' | tr -d '[:space:]')
if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
  VERIFIED=$(head -50 "${SCOPE_DIR}/manifest.md" | grep "^verified:" | head -1)
  if [ -z "$VERIFIED" ]; then
    emit_block_then_exit_2 "TRACEABILITY VERIFICATION WARNING

Manifest at ${SCOPE_DIR}/manifest.md has a source but no verified: stamp.
The handoff-verifier has not run."
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  emit_block_then_exit_2 "ENFORCEMENT ERROR: check-manifest.sh did not complete all checks"
fi
exit 0
