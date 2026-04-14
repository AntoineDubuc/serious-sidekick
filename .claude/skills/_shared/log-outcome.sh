#!/bin/bash
# _shared/log-outcome.sh — diagnostic outcome logging for Serious Sidekick hooks.
#
# DIAGNOSTIC ONLY. NOT A SECURITY CONTROL.
# The moment any hook, agent, or policy engine starts reading this log to make
# decisions, update this banner and commission a real security plan.
#
# Usage: source this file, then call:
#   _log_outcome VERDICT "reason"
#
# VERDICT must be one of: SKIP | ALLOW | BLOCK | PASS | ERROR
# reason is a short free-text tag (embedded newlines and tabs are stripped).
#
# Output: appends one TSV line to .claude/logs/outcomes.log with 7 fields:
#   ts_utc \t hook \t verdict \t file_path \t reason \t pid \t duration_ms
#
# Concurrent writes are NOT serialized (no locking). Line tearing is possible
# under simultaneous writes; acceptable for diagnostic use.

_log_outcome() {
  local verdict="${1:-}"
  local reason="${2:-}"

  # Enum guard
  case "$verdict" in
    SKIP|ALLOW|BLOCK|PASS|ERROR) ;;
    *)
      printf 'log_outcome: invalid verdict %q (must be SKIP|ALLOW|BLOCK|PASS|ERROR)\n' "$verdict" >&2
      return 1
      ;;
  esac

  # Strip newlines/tabs from reason — prevents TSV corruption + log injection
  reason="${reason//$'\n'/ }"
  reason="${reason//$'\t'/ }"
  reason="${reason//$'\r'/ }"

  # Resolve log path
  local project_root="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-.}}"
  local log_dir="${project_root}/.claude/logs"
  local log_path="${log_dir}/outcomes.log"

  # Create dir if missing; inherits umask
  mkdir -p "$log_dir" 2>/dev/null

  # Gather fields
  local ts_utc
  ts_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf 'unknown')"
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[1]:-$0}" 2>/dev/null || printf 'unknown')"
  local fp="${FILE_PATH:-}"
  # Strip newlines from file_path too (defensive)
  fp="${fp//$'\n'/ }"
  fp="${fp//$'\t'/ }"
  local pid=$$
  local duration_ms="${DURATION_MS:-}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$ts_utc" "$hook_name" "$verdict" "$fp" "$reason" "$pid" "$duration_ms" \
    >> "$log_path" 2>/dev/null

  return 0
}
