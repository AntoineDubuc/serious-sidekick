#!/bin/bash
# stop-hook-guard.sh — Shared guard utility for Claude Code Stop hooks
#
# Usage: source this file at the TOP of any Stop hook script.
#   source "$(dirname "$0")/../../_shared/stop-hook-guard.sh"
#   guard_stop_hook_active
#   guard_terminal_state "$OUTPUT_FILE" "status: done"
#   # ... hook-specific logic ...
#   emit_block_then_exit_2 "Reason for blocking"
#
# IMPORTANT: This utility reads stdin at source-time and caches it in
# _STOP_HOOK_GUARD_INPUT. If your hook needs the raw payload, read it
# from that variable — do NOT call $(cat) after sourcing this file,
# because stdin will already be consumed.
#
# Functions:
#   guard_stop_hook_active  — exits 0 if stop_hook_active=true (loop break)
#   guard_terminal_state    — exits 0 if terminal marker is absent
#   emit_advisory_then_exit_0 — prints advisory to stderr + exits 0
#   emit_block_then_exit_2    — prints block message to stderr + exits 2

# Cache stdin at source-time (stdin is single-shot — can only be read once)
_STOP_HOOK_GUARD_INPUT=$(cat)

# guard_stop_hook_active — Check if Claude is in a forced-continuation loop.
# If stop_hook_active is true, the hook should NOT run its logic — exit 0
# to break the loop. If stdin is empty, malformed, or missing the field,
# also exit 0 (fail-open: do not block on garbage input).
#
# Community interpretation confirmed empirically (Task 1, 2026-04-07):
#   stop_hook_active=true  → Claude is looping (a prior hook blocked)
#   stop_hook_active=false → normal clean stop
guard_stop_hook_active() {
  # If stdin is empty, malformed, or missing the field: RETURN (let hook run).
  # Only EXIT 0 when stop_hook_active is definitively "true" (loop confirmed).
  # This is conservative: if we can't determine loop state, run the hook.
  if [ -z "$_STOP_HOOK_GUARD_INPUT" ]; then
    return 0
  fi

  local stop_hook_active
  stop_hook_active=$(echo "$_STOP_HOOK_GUARD_INPUT" | jq -r 'if has("stop_hook_active") then (.stop_hook_active | tostring) else "" end' 2>/dev/null)

  if [ -z "$stop_hook_active" ]; then
    return 0
  fi

  if [ "$stop_hook_active" = "true" ]; then
    exit 0
  fi
}

# guard_terminal_state — Check if a file contains a terminal marker.
# If the marker is NOT present, exit 0 (the workflow is still in progress,
# no reason to block). If the marker IS present, return normally so the
# caller can run its blocking logic.
#
# Arguments:
#   $1 — path to the primary output file (e.g., conversation.md)
#   $2 — the terminal marker string to grep for (e.g., "status: done")
guard_terminal_state() {
  local file_path="$1"
  local terminal_marker="$2"

  if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
    exit 0
  fi

  if [ -z "$terminal_marker" ]; then
    exit 0
  fi

  if ! grep -q "$terminal_marker" "$file_path" 2>/dev/null; then
    exit 0
  fi
}

# emit_advisory_then_exit_0 — Print an advisory message to stderr and exit 0.
# Advisory messages are informational — they do NOT block Claude from exiting.
# All messages are DECLARATIVE (no imperatives like "Run X" or "Do Y").
#
# Arguments:
#   $1 — the advisory message text
emit_advisory_then_exit_0() {
  local message="$1"
  if [ -n "$message" ]; then
    echo "$message" >&2
  fi
  exit 0
}

# emit_block_then_exit_2 — Print a block message to stderr and exit 2.
# Exit 2 tells Claude Code to continue (the hook is blocking the stop).
# All messages are DECLARATIVE (no imperatives like "Run X" or "Do Y").
#
# Arguments:
#   $1 — the block reason message
emit_block_then_exit_2() {
  local message="$1"
  if [ -n "$message" ]; then
    echo "$message" >&2
  fi
  exit 2
}
