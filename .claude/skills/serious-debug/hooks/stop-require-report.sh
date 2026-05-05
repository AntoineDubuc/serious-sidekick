#!/bin/bash
# stop-require-report.sh — Logging stub for /serious-debug
# This is a Plan 1 stub. Real logic added in Plan 2.
#
# Exit codes:
#   0 = allow (always, for stubs)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# Source the per-session breadcrumb helper (claude_pid).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0

# Dual-read breadcrumb gate (Task 4 of multi-terminal-breadcrumb-collision-verify).
# Prefer the per-session path; fall back to legacy with a stderr WARN.
SKILL=debug
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

HOOK_EVENT="stop-require-report"
echo "[serious-debug] ${HOOK_EVENT} fired (stub — no action)" >&2

exit 0
