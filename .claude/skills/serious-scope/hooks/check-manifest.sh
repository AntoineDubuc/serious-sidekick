#!/bin/bash
# check-manifest.sh
# Stop hook for /serious-scope: warns if an active scope session
# has no manifest.md (scoping started but never produced output).
#
# Exit codes:
#   0 = allow exit (no active session, or manifest exists)
#   2 = block exit (active session without manifest)

# No active scope session? Allow exit.
[ ! -f ".active-scope" ] && exit 0

SCOPE_DIR=$(cat .active-scope | tr -d '[:space:]')

# No scope directory? Allow exit.
[ ! -d "$SCOPE_DIR" ] && exit 0

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

exit 0
