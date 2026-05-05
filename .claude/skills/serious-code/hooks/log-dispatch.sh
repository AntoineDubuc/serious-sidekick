#!/bin/bash
# log-dispatch.sh — PreToolUse/Agent hook for dispatch audit trail
#
# Silently logs every Agent dispatch during /serious-code runs.
# Appends one line per dispatch to {PLAN_DIR}/evidence/dispatch_log.md.
# Format: {ISO timestamp} | {task_id} | {subagent_type} | {tool_use_id}
#
# ALWAYS exits 0 — never blocks, never writes to stderr.
# If anything fails (no breadcrumb, no jq, bad JSON, etc.), exits silently.

# Pin jq at script start — exit 0 if not found
JQ=$(command -v jq) || exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"

# Source the per-session breadcrumb helper (claude_pid).
# shellcheck source=/dev/null
source "$(dirname "$0")/../../_shared/path-resolve.sh" || exit 0

# Dual-read breadcrumb gate (Task 4 of multi-terminal-breadcrumb-collision-verify).
# Prefer the per-session path; fall back to legacy with a stderr WARN.
SKILL=code
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
BREADCRUMB="$bc"

# Read plan dir from breadcrumb
PLAN_DIR=""
PLAN_DIR=$(cat "$BREADCRUMB" 2>/dev/null) || exit 0
[ -z "$PLAN_DIR" ] && exit 0

# Evidence dir must already exist — do NOT create it
EVIDENCE_DIR="${PROJECT_ROOT}/${PLAN_DIR}/evidence"
[ -d "$EVIDENCE_DIR" ] || exit 0

# Read hook input JSON from stdin
INPUT=""
INPUT=$(cat 2>/dev/null) || exit 0
[ -z "$INPUT" ] && exit 0

# Parse fields via jq — exit 0 on any parse failure
SUBAGENT_TYPE=""
SUBAGENT_TYPE=$("$JQ" -r '.tool_input.subagent_type // empty' <<< "$INPUT" 2>/dev/null) || exit 0
[ -z "$SUBAGENT_TYPE" ] && exit 0

TOOL_USE_ID=""
TOOL_USE_ID=$("$JQ" -r '.tool_use_id // empty' <<< "$INPUT" 2>/dev/null) || exit 0

PROMPT=""
PROMPT=$("$JQ" -r '.tool_input.prompt // empty' <<< "$INPUT" 2>/dev/null) || exit 0

# Extract TASK_ID from prompt — best effort, "unscoped" if not found
TASK_ID="unscoped"
EXTRACTED=""
EXTRACTED=$(printf '%s' "$PROMPT" | grep -oE 'TASK_ID: task_[0-9]+' | head -1 | sed 's/TASK_ID: //') || true
[ -n "$EXTRACTED" ] && TASK_ID="$EXTRACTED"

# Sanitize all fields: replace pipe with underscore, strip control chars, truncate to 200 bytes
sanitize() {
  printf '%s' "$1" \
    | sed 's/|/_/g' \
    | LC_ALL=C tr -d '\000-\037\177' \
    | cut -c1-200
}

TASK_ID=$(sanitize "$TASK_ID")
SUBAGENT_TYPE=$(sanitize "$SUBAGENT_TYPE")
TOOL_USE_ID=$(sanitize "$TOOL_USE_ID")

# Generate ISO timestamp
TIMESTAMP=""
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null) || TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S" 2>/dev/null) || exit 0

# Write log line with restricted permissions
LOG_FILE="${EVIDENCE_DIR}/dispatch_log.md"
(
  umask 077
  printf '%s | %s | %s | %s\n' "$TIMESTAMP" "$TASK_ID" "$SUBAGENT_TYPE" "$TOOL_USE_ID" >> "$LOG_FILE"
) 2>/dev/null || true

exit 0
