#!/bin/bash
# check-manifest.sh
# Stop hook for /serious-scope: warns if an active scope session
# has no manifest.md (scoping started but never produced output).
#
# Exit codes:
#   0 = allow exit (no active session, or manifest exists)
#   2 = block exit (active session without manifest)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0

# No active scope session? Allow exit.
[ ! -f "${PROJECT_ROOT}/.active-scope" ] && exit 0

BREADCRUMB_CONTENT=$(cat "${PROJECT_ROOT}/.active-scope" | tr -d '[:space:]')
case "$BREADCRUMB_CONTENT" in
  /* | *..* )
    echo "WARNING: breadcrumb content rejected (path traversal or absolute path)" >&2
    exit 0 ;;
esac
SCOPE_DIR="${PROJECT_ROOT}/${BREADCRUMB_CONTENT}"

# No scope directory? Allow exit.
[ ! -d "$SCOPE_DIR" ] && exit 0

# --- CHECKS_PASSED fail-closed pattern ---
# All grep -c invocations MUST use || true (returns exit 1 on zero matches)
CHECKS_PASSED=false

# Check for manifest.md
if [ ! -f "${SCOPE_DIR}/manifest.md" ]; then
  echo "SCOPE MANIFEST WARNING" >&2
  echo "" >&2
  echo "Active scope session at ${SCOPE_DIR} has no manifest.md." >&2
  echo "Scoping started but never produced a manifest." >&2
  echo "" >&2
  echo "To fix: complete /serious-scope to generate the manifest, or" >&2
  echo "run /serious-abandon to abandon this scope session." >&2
  exit 2
fi

# --- Extraction gate + verifier stamp (only when upstream source exists) ---
# Only require extraction and verification when the manifest has an upstream source.
# Scopes created from scratch (no source:) don't need extraction.
SOURCE=$(head -50 "${SCOPE_DIR}/manifest.md" | grep "^source:" | sed 's/source: *//' | tr -d '[:space:]')
if [ -n "$SOURCE" ] && [ "$SOURCE" != "" ]; then
  VERIFIED=$(head -50 "${SCOPE_DIR}/manifest.md" | grep "^verified:" | head -1)
  if [ -z "$VERIFIED" ]; then
    echo "TRACEABILITY VERIFICATION WARNING" >&2
    echo "" >&2
    echo "Manifest at ${SCOPE_DIR}/manifest.md has a source but no verified: stamp." >&2
    echo "The handoff-verifier has not run." >&2
    exit 2
  fi
fi

CHECKS_PASSED=true

# Final guard — if we never reached the pass marker, something failed silently
if [ "$CHECKS_PASSED" != "true" ]; then
  echo "ENFORCEMENT ERROR: check-manifest.sh did not complete all checks" >&2
  exit 2
fi
exit 0
