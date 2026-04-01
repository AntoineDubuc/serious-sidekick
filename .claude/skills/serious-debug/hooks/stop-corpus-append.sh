#!/bin/bash
# stop-corpus-append.sh — Logging stub for /serious-debug
# This is a Plan 1 stub. Real logic added in Plan 2.
#
# Exit codes:
#   0 = allow (always, for stubs)

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ ! -d "$PROJECT_ROOT" ] && exit 0
[ -f "$PROJECT_ROOT/.claude/settings.json" ] || echo "WARNING: CLAUDE_PROJECT_DIR may be incorrect: $PROJECT_ROOT" >&2

# No active debug session? Silent exit.
[ ! -f "${PROJECT_ROOT}/.active-debug" ] && exit 0

HOOK_EVENT="stop-corpus-append"
echo "[serious-debug] ${HOOK_EVENT} fired (stub — no action)" >&2

exit 0
